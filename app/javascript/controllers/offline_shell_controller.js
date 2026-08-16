import { Controller } from "@hotwired/stimulus"
import { read as readCatalog } from "lib/catalog_cache"
import * as cart from "lib/cart"
import * as identity from "lib/identity"
import { receiptHtml } from "lib/receipt"
import { computeBilling as computeBillingShared } from "lib/billing"
import { enqueueCheckout, attemptCheckout as runCheckoutFlow, ensureAuthorityQuietly, releaseAuthorityIfClean } from "lib/checkout_flow"
import { readCounter } from "lib/offline_invoice"

// The one HTML route the Service Worker may cache (OfflineShellsController,
// CLAUDE.md invariant #4) — hydrated entirely client-side, from IndexedDB
// only, so it works from a genuinely cold boot with zero server contact.
// Deliberately minimal compared to takeaway_checkout_controller.js: no
// search/filter, no category tabs, no held orders (server-only, cannot
// work offline — see design note in the plan), no fake card-terminal
// delay. The double-charge-prevention core (lib/checkout_flow.js) and the
// receipt layout (lib/receipt.js) are the SAME modules the online screen
// uses, not a second copy.
export default class extends Controller {
  static targets = [
    "identityLabel", "identityPicker", "identityList",
    "noCatalogState", "noAuthorityState", "orderingUi",
    "menu", "cartFooter", "payButton",
    "payBackdrop", "payPanel", "payContent",
    "charging", "pendingReceipt", "toast"
  ]

  async connect() {
    this.cart = cart.clear()
    this.catalog = await readCatalog()

    // Best-effort — this page is reachable with no signed-in session at
    // all, but if it happens to have connectivity right now (a tablet
    // that was rebooted while the WiFi is briefly back, say), topping up
    // the grant here means the next offline sale doesn't have to wait for
    // one to be acquired mid-checkout, same reasoning as the online
    // screen. Never blocks rendering — if it fails, the shell falls back
    // to the plain queued-retry receipt exactly as it does today.
    ensureAuthorityQuietly()
    this.authorityTimer = setInterval(() => ensureAuthorityQuietly(), 60000)

    if (!this.catalog) {
      this.show("noCatalogState")
      return
    }

    const counter = await readCounter()
    if (!counter) {
      this.show("noAuthorityState")
      return
    }

    const actingUserId = await identity.current()
    if (!actingUserId) {
      this.openIdentityPicker()
      return
    }

    this.actingUserId = actingUserId
    this.updateIdentityLabel()
    this.show("orderingUi")
    this.renderMenu()
    this.render()
  }

  disconnect() {
    if (this.authorityTimer) clearInterval(this.authorityTimer)
    releaseAuthorityIfClean()
  }

  show(targetName) {
    ["noCatalogState", "noAuthorityState", "orderingUi"].forEach((name) => {
      this[`${name}Target`].hidden = name !== targetName
    })
  }

  // --- identity ---
  async openIdentityPicker() {
    const users = await identity.availableUsers()
    this.identityListTarget.innerHTML = users.map((user) => `
      <button type="button" data-action="offline-shell#chooseIdentity" data-user-id="${user.id}"
              class="w-full min-h-[56px] px-4 rounded-ctl border-2 border-line-2 bg-card text-[17px] font-semibold text-left active:border-go">
        ${user.name}
      </button>`).join("")
    this.identityPickerTarget.hidden = false
  }

  async chooseIdentity(event) {
    const userId = Number(event.currentTarget.dataset.userId)
    await identity.select(userId)
    this.actingUserId = userId
    this.updateIdentityLabel()
    this.identityPickerTarget.hidden = true
    this.show("orderingUi")
    this.renderMenu()
    this.render()
  }

  updateIdentityLabel() {
    const user = (this.catalog.users || []).find((u) => u.id === this.actingUserId)
    this.identityLabelTarget.textContent = user ? user.name : this.t("choose_who")
  }

  // --- menu / cart ---
  renderMenu() {
    const items = this.catalog.menu_items || []
    this.menuTarget.innerHTML = items.map((item) => `
      <button type="button" data-action="offline-shell#addItem"
              data-menu-item-id="${item.id}" data-menu-item-name="${item.name}" data-menu-item-price="${item.price_paise}"
              class="p-3.5 rounded-tile border border-line bg-card text-left active:border-go active:bg-go-50">
        <p class="text-[15px] font-semibold truncate">${item.name}</p>
        <p class="text-[13px] text-ink-3 font-mono mt-0.5">${this.formatInr(item.price_paise)}</p>
      </button>`).join("")
  }

  addItem(event) {
    const { menuItemId, menuItemName, menuItemPrice } = event.currentTarget.dataset
    this.cart = cart.addItem(this.cart, {
      menuItemId: Number(menuItemId), name: menuItemName, unitPricePaise: Number(menuItemPrice)
    })
    this.render()
  }

  render() {
    const count = cart.itemCount(this.cart)
    const total = cart.totalPaise(this.cart)
    this.currentTotalPaise = total

    this.cartFooterTarget.hidden = count === 0
    if (count > 0) {
      this.payButtonTarget.textContent = `${this.t("pay")}  ${this.formatInr(total)}`
    }
  }

  computeBilling(taxablePaise) {
    return computeBillingShared({
      taxablePaise, gstRateBp: this.catalog.shop.gst_rate_bp, compositionScheme: this.catalog.shop.composition_scheme
    })
  }

  formatInr(paise) {
    const rupees = paise / 100
    return `₹${rupees.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }

  // --- payment ---
  openPayment() {
    if (this.cart.size === 0) return

    const billing = this.computeBilling(this.currentTotalPaise)
    this.payAmountDue = billing.totalPaise

    this.payContentTarget.innerHTML = `
      <div class="bg-shell rounded-ctl p-4 mb-4 text-center">
        <p class="text-[12px] text-ink-3 font-semibold uppercase tracking-wide mb-1">${this.t("amount_due")}</p>
        <p class="text-[32px] font-mono font-bold text-go">${this.formatInr(billing.totalPaise)}</p>
      </div>
      <p class="text-[12px] text-ink-3 font-semibold uppercase tracking-wide mb-2">${this.t("select_method")}</p>
      <div class="grid grid-cols-2 gap-2.5 mb-2">
        <button type="button" data-action="offline-shell#selectPayMethod" data-method="cash"
                class="flex flex-col items-center gap-1.5 p-4 rounded-ctl border-2 border-line-2 bg-shell active:border-go">
          <span class="text-[24px]">💵</span><span class="text-[14px] font-bold">${this.t("pay_method_cash")}</span>
        </button>
        <button type="button" data-action="offline-shell#selectPayMethod" data-method="other"
                class="flex flex-col items-center gap-1.5 p-4 rounded-ctl border-2 border-line-2 bg-shell active:border-go">
          <span class="text-[24px]">⋯</span><span class="text-[14px] font-bold">${this.t("pay_method_other")}</span>
        </button>
      </div>
      <div data-pay-detail></div>`

    this.payBackdropTarget.hidden = false
    this.payPanelTarget.hidden = false
    requestAnimationFrame(() => {
      this.payBackdropTarget.classList.remove("opacity-0")
      this.payBackdropTarget.classList.add("pointer-events-auto")
      this.payPanelTarget.classList.remove("translate-y-full")
    })
  }

  closePayment() {
    this.payPanelTarget.classList.add("translate-y-full")
    this.payBackdropTarget.classList.add("opacity-0")
    this.payBackdropTarget.classList.remove("pointer-events-auto")
    setTimeout(() => {
      this.payPanelTarget.hidden = true
      this.payBackdropTarget.hidden = true
    }, 300)
  }

  selectPayMethod(event) {
    const method = event.currentTarget.dataset.method
    this.payPanelTarget.querySelectorAll("[data-method]").forEach((btn) => {
      btn.classList.toggle("border-go", btn.dataset.method === method)
    })

    const detail = this.payPanelTarget.querySelector("[data-pay-detail]")
    detail.innerHTML = method === "cash" ? this.cashDetailHtml() : `
      <button type="button" data-action="offline-shell#confirmNonCash" data-method="${method}"
              class="w-full min-h-[56px] mt-4 rounded-tile text-[16px] font-bold bg-go text-surface active:bg-go-700">
        ${this.t("confirm_payment")}
      </button>`
  }

  cashDetailHtml() {
    return `
      <div class="mt-4">
        <p class="text-[12px] text-ink-3 font-semibold uppercase tracking-wide mb-2">${this.t("cash_received")}</p>
        <input type="text" inputmode="numeric" placeholder="${this.t("other_amount")}" data-action="input->offline-shell#typeCashAmount"
               class="w-full min-h-[48px] px-3 rounded-ctl border-2 border-line-2 font-mono text-[16px] mb-3">
        <div data-change-display class="mb-1"></div>
        <button type="button" data-action="offline-shell#confirmCash" data-confirm-cash disabled
                class="w-full min-h-[56px] mt-2 rounded-tile text-[16px] font-bold bg-go text-surface disabled:bg-key-2 disabled:text-ink-4">
          ${this.t("confirm_payment")}
        </button>
      </div>`
  }

  typeCashAmount(event) {
    const rupees = parseFloat(event.currentTarget.value) || 0
    this.cashReceivedPaise = Math.round(rupees * 100)
    const due = this.payAmountDue
    const change = this.cashReceivedPaise - due

    const display = this.payPanelTarget.querySelector("[data-change-display]")
    const confirmBtn = this.payPanelTarget.querySelector("[data-confirm-cash]")
    if (!display || !confirmBtn) return

    if (this.cashReceivedPaise <= 0) {
      display.innerHTML = ""
      confirmBtn.disabled = true
    } else if (change < 0) {
      display.innerHTML = `<div class="px-4 py-3 rounded-ctl bg-stop-50 border border-stop text-stop text-[14px] font-semibold text-center">${this.t("insufficient_amount")}</div>`
      confirmBtn.disabled = true
    } else {
      display.innerHTML = `
        <div class="flex items-center justify-between px-4 py-3 rounded-ctl bg-go text-surface">
          <span class="text-[15px] font-semibold">${this.t("change_due")}</span>
          <span class="text-[22px] font-mono font-bold">${this.formatInr(change)}</span>
        </div>`
      confirmBtn.disabled = false
    }
  }

  confirmCash() {
    if (!this.cashReceivedPaise || this.cashReceivedPaise < this.payAmountDue) return
    this.completeCheckout("cash")
  }

  confirmNonCash(event) {
    this.completeCheckout(event.currentTarget.dataset.method)
  }

  // --- checkout ---
  async completeCheckout(method) {
    const items = Array.from(this.cart.values())
    const clientSessionToken = crypto.randomUUID()

    const entry = await enqueueCheckout({
      kind: "takeaway_checkout",
      payload: {
        client_session_token: clientSessionToken,
        acting_user_id: this.actingUserId,
        method,
        items: items.map((item) => ({
          menu_item_id: item.menuItemId, quantity: item.quantity,
          name: item.name, unit_price_paise: item.unitPricePaise
        })),
        client_token: crypto.randomUUID()
      }
    })

    this.cart = cart.clear()
    this.render()
    this.closePayment()

    const shop = {
      gstRateBp: this.catalog.shop.gst_rate_bp, compositionScheme: this.catalog.shop.composition_scheme,
      invoicePrefix: this.catalog.shop.invoice_prefix
    }
    const tableSession = { clientSessionToken }
    const receiptPayload = { items: items.map((item) => ({ name: item.name, unitPricePaise: item.unitPricePaise, quantity: item.quantity })) }

    await runCheckoutFlow({
      entryId: entry.id, items, method, shop, tableSession, actingUserId: this.actingUserId,
      callbacks: {
        onCharging: (retry) => this.showCharging(retry),
        onApplied: () => this.startNewOrder(),
        onRejected: () => {
          this.chargingTarget.hidden = true
          this.showToast(this.t("checkout_failed"))
        },
        onIssuedOffline: (invoice) => this.showIssuedReceipt(invoice),
        onPendingOffline: () => this.showPendingReceipt(receiptPayload)
      }
    })
  }

  showCharging(isRetry) {
    this.chargingTarget.hidden = false
    this.chargingTarget.querySelector("[data-charging-label]").textContent =
      this.t(isRetry ? "charging_offline" : "charging")
  }

  showPendingReceipt(payload) {
    const billing = this.computeBilling(payload.items.reduce((sum, item) => sum + item.quantity * Number(item.unitPricePaise), 0))
    this.renderReceipt({ items: payload.items, billing, invoiceNumber: null, issuedAt: new Date() })
  }

  showIssuedReceipt(invoice) {
    const billing = {
      taxablePaise: invoice.taxablePaise, cgstPaise: invoice.cgstPaise,
      sgstPaise: invoice.sgstPaise, totalPaise: invoice.totalPaise
    }
    this.renderReceipt({ items: invoice.items, billing, invoiceNumber: invoice.number, issuedAt: new Date(invoice.issuedAt) })
  }

  renderReceipt({ items, billing, invoiceNumber, issuedAt }) {
    const shop = this.catalog.shop
    this.pendingReceiptTarget.innerHTML = receiptHtml({
      tableLabel: this.catalog.takeaway_counter?.label || "",
      shopName: shop.name, shopAddress: shop.address,
      shopGstin: shop.gstin, shopFssai: shop.fssai_licence, shopFooter: shop.invoice_footer,
      items, billing, invoiceNumber, issuedAt,
      compositionScheme: shop.composition_scheme,
      formatInr: (paise) => this.formatInr(paise),
      strings: {
        printReceipt: this.t("print_receipt"),
        newOrder: this.t("new_order"),
        newOrderAction: "offline-shell#startNewOrder",
        invoiceNumber: this.t("invoice_number"),
        subtotal: this.t("subtotal"),
        cgst: this.t("cgst"),
        sgst: this.t("sgst"),
        total: this.t("total"),
        compositionDeclaration: this.t("composition_declaration")
      }
    })

    this.pendingReceiptTarget.hidden = false
    this.chargingTarget.hidden = true
  }

  // Clears the cart and re-renders in place — deliberately NOT a link to
  // /takeaway (a server route that doesn't exist from this offline shell's
  // point of view; see the online screen's equivalent, which can rely on
  // the server being reachable in that context).
  startNewOrder() {
    this.pendingReceiptTarget.hidden = true
    this.cart = cart.clear()
    this.render()
  }

  showToast(message) {
    this.toastTarget.textContent = message
    this.toastTarget.hidden = false
    requestAnimationFrame(() => this.toastTarget.classList.remove("opacity-0"))
    setTimeout(() => {
      this.toastTarget.classList.add("opacity-0")
      setTimeout(() => { this.toastTarget.hidden = true }, 200)
    }, 2500)
  }

  t(key) {
    const locale = document.documentElement.lang
    const strings = {
      choose_who: { en: "Choose who's working", ne: "काम गर्ने व्यक्ति छान्नुहोस्" },
      pay: { en: "Pay", ne: "तिर्नुहोस्" },
      amount_due: { en: "Amount due", ne: "तिर्नुपर्ने रकम" },
      select_method: { en: "Select method", ne: "माध्यम छान्नुहोस्" },
      pay_method_cash: { en: "Cash", ne: "नगद" },
      pay_method_other: { en: "Other", ne: "अन्य" },
      cash_received: { en: "Cash received", ne: "प्राप्त नगद" },
      other_amount: { en: "Other amount", ne: "अर्को रकम" },
      change_due: { en: "Change due", ne: "फिर्ता रकम" },
      insufficient_amount: { en: "Insufficient amount", ne: "रकम अपुग छ" },
      confirm_payment: { en: "Confirm payment", ne: "भुक्तानी पक्का गर्नुहोस्" },
      charging: { en: "Charging...", ne: "भुक्तानी हुँदैछ..." },
      charging_offline: { en: "Waiting for internet — will send automatically", ne: "इन्टरनेट पर्खँदै — पुनः प्रयास हुँदैछ" },
      checkout_failed: { en: "Checkout could not be completed — ask an admin", ne: "चेकआउट पूरा हुन सकेन — admin लाई सोध्नुहोस्" },
      print_receipt: { en: "Print receipt", ne: "रसिद छाप्नुहोस्" },
      invoice_number: { en: "Invoice", ne: "बीजक" },
      new_order: { en: "Start new order", ne: "नयाँ अर्डर सुरु गर्नुहोस्" },
      subtotal: { en: "Subtotal", ne: "मूल्य" },
      cgst: { en: "CGST", ne: "मू.अ.कर (CGST)" },
      sgst: { en: "SGST", ne: "मू.अ.कर (SGST)" },
      composition_declaration: { en: "Composition taxable person, not eligible to collect tax on supplies", ne: "Composition taxable person, not eligible to collect tax on supplies" },
      total: { en: "Total", ne: "जम्मा" }
    }
    return strings[key][locale] || strings[key].en
  }
}
