import { seedCounter, readCounter } from "lib/offline_invoice"

// Client-side lifecycle for the InvoiceAuthority grant (app/models/invoice_authority.rb).
// This module never decides on its own whether it's SAFE to issue offline —
// it only tracks whether THIS device currently holds the grant, seeded from
// the server's own response. The actual safety guarantee (at most one live
// grant per shop) lives entirely server-side, enforced by a DB constraint
// (db/migrate/*_create_invoice_authority_grants) and Billing.issue_invoice!'s
// guard — nothing here needs to duplicate that logic, only respect it.
let currentGrant = null

export function hasGrant() {
  return currentGrant !== null
}

export async function acquire() {
  const response = await fetch("/sync/invoice_authority", {
    method: "POST",
    headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content }
  })

  if (!response.ok) return null

  const grant = await response.json()
  currentGrant = grant
  await seedCounter({ grantId: grant.id, financialYear: grant.financial_year, sequence: grant.granted_sequence })
  return grant
}

export async function release() {
  if (!currentGrant) return

  await fetch("/sync/invoice_authority", {
    method: "DELETE",
    headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content }
  })
  currentGrant = null
}

// Called on app boot to pick up a grant this device already held (e.g. the
// page reloaded mid-offline-shift) — the local counter is still in
// IndexedDB even though the in-memory currentGrant was reset by the reload.
export async function resume() {
  const counter = await readCounter()
  if (counter) currentGrant = { id: counter.grantId, financial_year: counter.financialYear, granted_sequence: counter.sequence }
  return currentGrant
}
