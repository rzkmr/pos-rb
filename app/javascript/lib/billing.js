// Mirrors Billing.compute exactly (app/models/billing.rb) — extracts VAT
// and service charge backward out of the gross total (menu prices are
// gross/tax-inclusive, CLAUDE.md invariant #2; extraction order is fixed,
// invariant #3). Extracted to one shared module (previously duplicated
// inline in takeaway_checkout_controller.js) because this now also
// produces the numbers on offline-issued invoices (see
// lib/offline_invoice.js) — a genuine invoice's tax math, not just an
// on-screen preview, so it may not drift from the server's
// Billing.compute. The server independently recomputes and hard-rejects
// any mismatch at sync time (Sync::OfflineInvoiceIngest) as a backstop
// against exactly that drift.
export function computeBilling({ grossPaisa, vatRateBp, serviceChargeRateBp }) {
  const taxableBeforeVat = Math.round(grossPaisa / (1 + vatRateBp / 10000))
  const vatPaisa = grossPaisa - taxableBeforeVat

  const basePaisa = Math.round(taxableBeforeVat / (1 + serviceChargeRateBp / 10000))
  const serviceChargePaisa = taxableBeforeVat - basePaisa

  return { basePaisa, serviceChargePaisa, vatPaisa, grossPaisa }
}
