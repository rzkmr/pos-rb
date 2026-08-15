// Mirrors Billing.compute exactly (app/models/billing.rb) — CGST+SGST split
// on the half rate, round-off to the nearest rupee, zero tax under
// composition scheme (CLAUDE.md invariant #7). Extracted to one shared
// module (previously duplicated inline in takeaway_checkout_controller.js)
// because this now also produces the numbers on offline-issued invoices
// (see lib/offline_invoice.js) — a genuine invoice's tax math, not just an
// on-screen preview, so it may not drift from the server's Billing.compute.
// The server independently recomputes and hard-rejects any mismatch at
// sync time (Sync::OfflineInvoiceIngest) as a backstop against exactly
// that drift.
export function computeBilling({ taxablePaise, gstRateBp, compositionScheme }) {
  if (compositionScheme) {
    return { taxablePaise, cgstPaise: 0, sgstPaise: 0, roundOffPaise: 0, totalPaise: taxablePaise }
  }

  const halfRateBp = gstRateBp / 2
  const cgstPaise = Math.round((taxablePaise * halfRateBp) / 10000)
  const sgstPaise = cgstPaise
  const preRoundTotal = taxablePaise + cgstPaise + sgstPaise
  const totalPaise = Math.round(preRoundTotal / 100) * 100
  const roundOffPaise = totalPaise - preRoundTotal

  return { taxablePaise, cgstPaise, sgstPaise, roundOffPaise, totalPaise }
}
