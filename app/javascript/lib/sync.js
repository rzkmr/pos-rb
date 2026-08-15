import { pending, markSending, markApplied, markDuplicate, markRejected, markFailedRetryable, markAuthRequired } from "lib/outbox"

// Single drain loop for the whole outbox — deliberately not per-controller.
// One loop is far easier to reason about at 9pm during service than N
// independent retry timers, and it guarantees strict submission order,
// which matters: a void must never reach the server before the ticket it
// voids does.
//
// Runs on `pos:connectivity` -> online and on a timer while entries are
// pending, with backoff on failure. Never runs two drains concurrently —
// concurrency plus retries is how the same action ends up applied twice
// from the client's perspective even with a server-side idempotency guard.
const BASE_BACKOFF_MS = 5000
const MAX_BACKOFF_MS = 60000
const RETRY_TIMER_MS = 5000

let draining = false
let backoffMs = BASE_BACKOFF_MS
let retryTimeout = null
let listenersAttached = false

export function start() {
  if (listenersAttached) return
  listenersAttached = true

  document.addEventListener("pos:connectivity", (event) => {
    if (event.detail.state === "online") {
      backoffMs = BASE_BACKOFF_MS
      drain()
    }
  })

  scheduleNextDrain(RETRY_TIMER_MS)
  drain()
}

function scheduleNextDrain(delayMs) {
  if (retryTimeout) clearTimeout(retryTimeout)
  retryTimeout = setTimeout(() => {
    drain().finally(() => scheduleNextDrain(backoffMs))
  }, delayMs)
}

export async function drain() {
  if (draining) return
  draining = true

  // Captured once, up front — every mark* call below operates on THIS
  // list, never a fresh pending() lookup, because pending() only returns
  // "pending"/"failed_retryable" entries and markSending immediately
  // moves them to "sending". Re-querying pending() after that would find
  // nothing and silently strand every in-flight entry as "sending"
  // forever if the request then fails.
  let queue = []

  try {
    queue = await pending()
    if (queue.length === 0) return

    await Promise.all(queue.map((entry) => markSending(entry.id)))

    const response = await fetch("/sync/actions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify({
        actions: queue.map((entry) => ({ client_action_id: entry.id, kind: entry.kind, payload: entry.payload }))
      })
    })

    if (response.status === 401 || response.redirected) {
      // A long-offline device's Rails session may have expired — retrying
      // with the same expired session forever would just waste requests.
      // A human needs to sign back in before this can drain further.
      await Promise.all(queue.map((entry) => markAuthRequired(entry.id)))
      return
    }

    if (!response.ok) throw new Error(`sync failed: ${response.status}`)

    const body = await response.json()
    await applyResults(queue, body.results)
    backoffMs = BASE_BACKOFF_MS
  } catch {
    await Promise.all(queue.map((entry) => markFailedRetryable(entry.id, "network error")))
    backoffMs = Math.min(backoffMs * 2, MAX_BACKOFF_MS)
  } finally {
    draining = false
  }
}

async function applyResults(queue, results) {
  const byId = new Map(results.map((result) => [ result.client_action_id, result ]))

  for (const entry of queue) {
    const result = byId.get(entry.id)
    if (!result) {
      await markFailedRetryable(entry.id, "no result returned")
      continue
    }

    if (result.status === "applied") await markApplied(entry.id, result.result)
    else if (result.status === "duplicate") await markDuplicate(entry.id, result.result)
    else if (result.status === "rejected") await markRejected(entry.id, result.error)
    else await markFailedRetryable(entry.id, `unexpected status: ${result.status}`)
  }
}
