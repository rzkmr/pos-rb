// Pure receipt HTML builder — takes plain data, returns an HTML string.
// Shared by the online takeaway checkout screen and the offline shell so
// there is exactly one receipt layout, not two that can quietly diverge
// (this is a customer-facing legal document once it has an invoice number
// — see CLAUDE.md invariant #5/#6). Mirrors EscposReceipt's field order
// (design_system §2.5) so what's on screen matches the thermal printout.
//
// strings is the caller's t() lookup table narrowed to just the keys this
// module needs — passed in rather than imported so this stays framework-
// and locale-source agnostic.
export function receiptHtml({
  tableLabel, shopName, shopAddress, shopPan, shopFooter,
  items, billing, invoiceNumber, issuedAt, formatNpr, strings,
  provisional = false, newOrderHref = null
}) {
  const dateStr = formatReceiptDate(issuedAt)

  const itemRows = items.map((item) => `
    <div class="flex justify-between gap-3 text-[13px] py-0.5">
      <span class="flex-1">${item.quantity} x ${item.name}</span>
      <span>${formatNpr(item.quantity * Number(item.unitPricePaisa))}</span>
    </div>`).join("")

  const taxRows = `
    <div class="flex justify-between text-[13px]"><span>${strings.serviceCharge}</span><span>${formatNpr(billing.serviceChargePaisa)}</span></div>
    <div class="flex justify-between text-[13px]"><span>${strings.vat}</span><span>${formatNpr(billing.vatPaisa)}</span></div>`

  return `
    <header class="flex items-center gap-3 px-4 pt-[max(1rem,env(safe-area-inset-top))] pb-3">
      <h1 class="text-[19px] font-bold flex-1">${tableLabel}</h1>
    </header>
    <div class="p-4 flex flex-col items-center gap-4 w-full">
      ${provisional ? `<div class="w-full max-w-[340px] px-3 py-2 rounded-ctl bg-warn-50 border-2 border-warn-700 text-warn-900 text-[13px] font-bold text-center">${strings.provisionalNotice}</div>` : ""}
      <div class="receipt-print-root">
        <div class="receipt-preview rounded-ctl border border-line-2 shadow-sm p-4">
          <div class="text-center">
            <p class="font-bold text-[16px]">${shopName}</p>
            ${shopAddress ? `<p class="text-[12px]">${shopAddress}</p>` : ""}
            ${!provisional && shopPan ? `<p class="text-[12px]">PAN: ${shopPan}</p>` : ""}
          </div>
          <div class="receipt-rule my-2"></div>
          ${provisional ? `<p class="text-[13px] font-bold uppercase">${strings.provisionalHeading}</p>` : ""}
          ${invoiceNumber ? `<p class="text-[13px]">${strings.invoiceNumber} ${invoiceNumber}</p>` : ""}
          <p class="text-[13px]">${dateStr}</p>
          <p class="text-[13px]">${tableLabel}</p>
          <div class="receipt-rule my-2"></div>
          ${itemRows}
          <div class="receipt-rule my-2"></div>
          <div class="flex justify-between text-[13px]"><span>${strings.subtotal}</span><span>${formatNpr(billing.basePaisa)}</span></div>
          ${provisional ? "" : taxRows}
          <div class="receipt-rule my-2"></div>
          <div class="flex justify-between text-[16px] font-bold"><span>${strings.total}</span><span>${formatNpr(billing.grossPaisa)}</span></div>
          <div class="receipt-rule my-2"></div>
          ${shopFooter ? `<p class="text-center text-[12px] mt-1">${shopFooter}</p>` : ""}
        </div>
      </div>
      <div class="w-full max-w-[340px] flex flex-col gap-2.5">
        <button type="button" onclick="window.print()"
                class="w-full min-h-[64px] rounded-tile text-[18px] font-bold bg-go text-surface active:bg-go-700">
          ${strings.printReceipt}
        </button>
        ${newOrderHref
          ? `<a href="${newOrderHref}" class="text-center min-h-[56px] flex items-center justify-center rounded-tile text-[15px] font-bold bg-key text-ink active:bg-key-2">${strings.newOrder}</a>`
          : `<button type="button" data-action="${strings.newOrderAction}" class="text-center min-h-[56px] flex items-center justify-center rounded-tile text-[15px] font-bold bg-key text-ink active:bg-key-2">${strings.newOrder}</button>`}
      </div>
    </div>`
}

function formatReceiptDate(issuedAt) {
  return `${String(issuedAt.getDate()).padStart(2, "0")}-${issuedAt.toLocaleString("en", { month: "short" })}-${issuedAt.getFullYear()} ${String(issuedAt.getHours()).padStart(2, "0")}:${String(issuedAt.getMinutes()).padStart(2, "0")}`
}
