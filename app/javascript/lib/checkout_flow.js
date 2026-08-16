import { enqueue, entryStatus, cancel as cancelOutboxEntry } from "lib/outbox"
import { drain } from "lib/sync"
import { issueLocal, FyRolledOver } from "lib/offline_invoice"
import { acquire as acquireAuthority, resume as resumeAuthority } from "lib/invoice_authority_client"

// The double-charge-prevention core, shared by the online takeaway
// checkout screen and the offline shell. This is deliberately the ONLY
// place that decides how a checkout escalates from "try the server" to
// "issue a real invoice locally" — two independent copies of this logic
// is how the same sale ends up recorded twice. See CLAUDE.md invariant #2.
//
// enqueueCheckout persists the checkout as an outbox entry (kind:
// "takeaway_checkout" or "submit_ticket", see Sync::Replay::HANDLERS) —
// callers build the payload themselves since the online screen and the
// offline shell shape it slightly differently (table_session_id vs
// client_session_token).
export async function enqueueCheckout({ kind, payload }) {
  return enqueue({ kind, payload })
}

// Drives one checkout entry through: try online (drain) -> applied/rejected
// terminal, or -> fall back to issuing a real invoice offline -> or fall
// back further to the plain queued-retry state. Calls exactly one of the
// callbacks per invocation; the caller owns all rendering.
//
//   onCharging(isRetry)              — about to attempt/retry
//   onApplied()                      — succeeded online, safe to reload/move on
//   onRejected()                     — permanently rejected server-side
//   onIssuedOffline(invoiceRecord)   — a real, numbered invoice was issued locally
//   onPendingOffline()               — still queued, will retry; render the
//                                       provisional/pending state and schedule
//                                       another attempt yourself if desired
export async function attemptCheckout({ entryId, items, method, shop, tableSession, isRetry = false, callbacks }) {
  callbacks.onCharging?.(isRetry)

  await drain()
  const status = await entryStatus(entryId)

  if (status === "applied") {
    callbacks.onApplied?.()
    return "applied"
  }

  if (status === "rejected") {
    callbacks.onRejected?.()
    return "rejected"
  }

  // Still pending/failed_retryable/sending after a drain attempt means the
  // server genuinely isn't reachable right now — only then attempt to
  // issue offline.
  const issued = await tryIssueOffline({ entryId, items, method, shop, tableSession })
  if (issued) {
    callbacks.onIssuedOffline?.(issued)
    return "issued_offline"
  }

  callbacks.onPendingOffline?.()
  return "pending_offline"
}

// Returns the issued invoice record on success, or null to fall back to
// the plain outbox-queue retry — null covers every case where issuing
// offline isn't safe or possible right now: no grant could be acquired
// (Billing.issue_invoice!'s guard, or another device already holds one),
// or the device's clock has crossed a financial-year boundary since the
// grant was seeded (lib/offline_invoice.js refuses outright rather than
// guess how the new FY's sequence should start — that decision belongs to
// the server).
async function tryIssueOffline({ entryId, items, method, shop, tableSession }) {
  let grant = await resumeAuthority()
  if (!grant) grant = await acquireAuthority()
  if (!grant) return null

  try {
    const invoice = await issueLocal({ shop, tableSession, items, method })
    await cancelOutboxEntry(entryId)
    return invoice
  } catch (error) {
    if (error instanceof FyRolledOver) return null
    return null
  }
}
