import { unreportedInvoices, markReported } from "lib/offline_invoice"
import { release as releaseAuthority } from "lib/invoice_authority_client"

// Reports every offline-issued invoice still sitting in the local ledger
// to Sync::InvoicesController, once the device is back online. See
// Sync::OfflineInvoiceIngest for what the server does with these — turns
// them into real Invoice rows and advances the shop's counter to match.
export async function reportPending() {
  const pending = await unreportedInvoices()
  if (pending.length === 0) return { reported: 0 }

  const records = pending.map((invoice) => ({
    id: invoice.id,
    sequence: invoice.sequence,
    table_session_id: invoice.tableSessionId,
    method: invoice.method,
    client_token: invoice.id,
    items: invoice.items.map((item) => ({ menu_item_id: item.menuItemId, quantity: item.quantity })),
    total_paise: invoice.totalPaise,
    issued_at: invoice.issuedAt
  }))

  const response = await fetch("/sync/invoices", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
    },
    body: JSON.stringify({ records })
  })

  if (!response.ok) return { reported: 0, error: true }

  const body = await response.json()
  await Promise.all(body.results.map((result) => markReported(result.client_action_id)))

  // The server released the grant as the last step of a fully successful
  // ingest (Sync::OfflineInvoiceIngest#call) — mirror that locally so this
  // device stops treating itself as the offline invoice authority.
  await releaseAuthority()

  return { reported: body.results.length }
}
