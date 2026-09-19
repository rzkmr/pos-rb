import { get, getAll, put, transaction } from "lib/local_store"
import { computeBilling } from "lib/billing"
import { fiscalYearFor } from "lib/bikram_sambat"

// Client-side counter + ledger for real, fully-numbered invoices issued
// while the takeaway counter is offline. Safe ONLY because InvoiceAuthority
// guarantees this device is the sole writer for the shop's invoice
// sequence while it holds the grant (see Billing.issue_invoice!'s guard) —
// this module has no locking of its own and doesn't need any, since
// there's only ever one browser tab issuing from one IndexedDB.
const COUNTER_KEY = "invoice_counter"

// Mirrors BikramSambat.fiscal_year_for exactly (app/lib/bikram_sambat.rb)
// via lib/bikram_sambat.js's own lookup-table port — Nepal's fiscal year
// runs Shrawan 1 to Ashad end (CLAUDE.md invariant #8), not 1 April.
export const financialYearFor = fiscalYearFor

export async function seedCounter({ grantId, financialYear, sequence }) {
  await put("ledger", { id: COUNTER_KEY, grantId, financialYear, sequence })
}

export async function readCounter() {
  return get("ledger", COUNTER_KEY)
}

export const FyRolledOver = class extends Error {}

// Issues one real invoice locally: increments the counter and writes the
// invoice record in a single IndexedDB transaction so the two can never
// drift apart (a crash between them would otherwise either burn a number
// with no invoice behind it, or produce two invoices sharing one number).
//
// Refuses outright — does not attempt to "just start a new FY locally" —
// if the device's cached financial year no longer matches what the
// device's own clock computes. Deciding when a new financial year's
// sequence starts belongs to the server (Shop#next_invoice_sequence!,
// reload_invoice_fy_if_rolled_over!), not to a client that's been offline
// across the boundary. Callers must catch FyRolledOver and fall back to
// queuing an ordinary online checkout instead.
// tableSession is either { id } — the normal online screen, a real
// server-known TableSession — or { clientSessionToken } — the offline
// shell, which has never talked to the server and can only supply the
// same client-generated token Sync::OfflineInvoiceIngest resolves via
// TableSession.resolve_for_takeaway!. Exactly one is expected to be set;
// offline_invoice_sync.js reports whichever is present.
export async function issueLocal({ shop, tableSession, items, method, actingUserId = null }) {
  const counter = await readCounter()
  if (!counter) throw new Error("no local invoice counter — device does not hold offline invoice authority")

  const currentFy = financialYearFor(new Date())
  if (currentFy !== counter.financialYear) throw new FyRolledOver(`cached FY ${counter.financialYear}, device clock says ${currentFy}`)

  const grossPaisa = items.reduce((sum, item) => sum + item.quantity * Number(item.unitPricePaisa), 0)
  const billing = computeBilling({ grossPaisa, vatRateBp: shop.vatRateBp, serviceChargeRateBp: shop.serviceChargeRateBp })

  const nextSequence = counter.sequence + 1
  const number = `${shop.invoicePrefix}/${counter.financialYear}/${String(nextSequence).padStart(5, "0")}`
  const issuedAt = new Date().toISOString()

  const invoiceRecord = {
    id: crypto.randomUUID(),
    grantId: counter.grantId,
    number,
    sequence: nextSequence,
    financialYear: counter.financialYear,
    issuedAt,
    tableSessionId: tableSession.id ?? null,
    clientSessionToken: tableSession.clientSessionToken ?? null,
    actingUserId,
    method,
    items,
    basePaisa: billing.basePaisa,
    serviceChargePaisa: billing.serviceChargePaisa,
    vatPaisa: billing.vatPaisa,
    grossPaisa: billing.grossPaisa,
    reportedAt: null
  }

  await transaction(["ledger"], (stores) => {
    stores.ledger.put({ id: COUNTER_KEY, grantId: counter.grantId, financialYear: counter.financialYear, sequence: nextSequence })
    stores.ledger.put(invoiceRecord)
  })

  return invoiceRecord
}

export async function unreportedInvoices() {
  const all = await getAll("ledger")
  return all.filter((record) => record.id !== COUNTER_KEY && !record.reportedAt)
}

export async function markReported(invoiceId) {
  const record = await get("ledger", invoiceId)
  if (!record) return
  await put("ledger", { ...record, reportedAt: new Date().toISOString() })
}
