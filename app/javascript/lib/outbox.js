import { get, getAll, put, remove } from "lib/local_store"

// Durable, ordered queue of writes not yet confirmed by the server.
// Replaces the two ad-hoc localStorage retry schemes that used to live in
// takeaway_checkout_controller.js and order_cart_controller.js — those
// used a SINGLE-SLOT key per table session, so a second checkout queued
// while the first was still retrying silently overwrote it. This is an
// ordered list, so nothing gets lost that way.
//
// Every entry keeps its id (== client_action_id, used for server-side
// idempotency too) for its whole life; entries are replaced wholesale on
// state change, never mutated in place. Sent entries are kept for 24h so
// pending_badge_controller.js can show recent history, then swept.
const SENT_RETENTION_MS = 24 * 60 * 60 * 1000

export async function enqueue({ kind, payload, dependsOn = null }) {
  const entry = {
    id: crypto.randomUUID(),
    kind,
    payload,
    dependsOn,
    status: "pending",
    attempts: 0,
    lastError: null,
    createdAt: Date.now(),
    sentAt: null
  }
  await put("outbox", entry)
  return entry
}

// "sending" is included alongside "pending"/"failed_retryable" because a
// page reload mid-drain leaves entries stuck at "sending" with no actual
// in-flight request behind them anymore — they need to be picked up again,
// not stranded. sync.js's drain() is never concurrent with itself, so
// re-sending a "sending" entry from a fresh page load is always safe.
const RESUMABLE_STATUSES = [ "pending", "failed_retryable", "sending" ]

export async function pending() {
  const all = await getAll("outbox")
  return all
    .filter((entry) => RESUMABLE_STATUSES.includes(entry.status))
    .sort((a, b) => a.createdAt - b.createdAt)
}

export async function all() {
  await sweepOldSent()
  const entries = await getAll("outbox")
  return entries.sort((a, b) => a.createdAt - b.createdAt)
}

export async function entryStatus(id) {
  const entry = await get("outbox", id)
  return entry ? entry.status : null
}

export async function markSending(id) {
  const entry = await get("outbox", id)
  if (!entry) return
  await put("outbox", { ...entry, status: "sending" })
}

export async function markApplied(id, result) {
  const entry = await get("outbox", id)
  if (!entry) return
  await put("outbox", { ...entry, status: "applied", sentAt: Date.now(), result })
}

// A "duplicate" result means the server already had this action recorded
// (a previous attempt succeeded but the client never saw the response) —
// treated the same as applied.
export async function markDuplicate(id, result) {
  return markApplied(id, result)
}

// A permanently-rejected entry (bad reference, stale transition, ...) is
// moved out of the pending set so it can't block entries queued after it —
// see sync.js's head-of-line handling.
export async function markRejected(id, error) {
  const entry = await get("outbox", id)
  if (!entry) return
  await put("outbox", { ...entry, status: "rejected", lastError: error })
}

export async function markFailedRetryable(id, error) {
  const entry = await get("outbox", id)
  if (!entry) return
  await put("outbox", { ...entry, status: "failed_retryable", attempts: entry.attempts + 1, lastError: error })
}

// A device offline long enough that its Rails session expired needs a
// human to sign in again before anything can drain — see sync.js. Distinct
// from failed_retryable because retrying with the same expired session
// forever would just waste requests.
export async function markAuthRequired(id) {
  const entry = await get("outbox", id)
  if (!entry) return
  await put("outbox", { ...entry, status: "auth_required" })
}

// Removes a queued action outright rather than letting it drain normally —
// used when a takeaway_checkout entry is superseded by a locally-issued
// offline invoice (lib/offline_invoice.js): the two must never both reach
// the server, or the same sale gets recorded twice under two different
// client_action_ids.
export async function cancel(id) {
  await remove("outbox", id)
}

async function sweepOldSent() {
  const entries = await getAll("outbox")
  const cutoff = Date.now() - SENT_RETENTION_MS
  await Promise.all(
    entries
      .filter((entry) => entry.status === "applied" && entry.sentAt && entry.sentAt < cutoff)
      .map((entry) => remove("outbox", entry.id))
  )
}
