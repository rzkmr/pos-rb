import { Controller } from "@hotwired/stimulus"
import { enqueue, all as allOutboxEntries, entryStatus } from "lib/outbox"
import { drain } from "lib/sync"

// Counter checkout: build a cart, pick a payment method, confirm. That
// single request submits the ticket (which fires to the kitchen immediately
// via Ticket's broadcasts_refreshes_to — see Sync::Handlers::TakeawayCheckout,
// which mirrors TakeawayCheckoutsController#create), pays the exact total
// in full, issues the invoice, and queues the print job. Idempotent the
// same way order-cart is: a client_token is generated once and enqueued
// via the shared offline outbox (lib/outbox.js) before anything is sent,
// so a retry after a network blip never double-submits or double-charges
// (see CLAUDE.md invariant #2).
//
// Cash received / change due (design_system §8.2) is a cashier aid only —
// the server always charges the exact total; nothing about the tendered
// amount is ever sent.
export default class extends Controller {
  static targets = [
    "itemRow", "rowQty", "categoryTab", "itemList", "noSearchResults",
    "search", "searchClear", "clock",
    "cartListDesktop", "cartFooterDesktop", "cartListMobile", "cartFooterMobile",
    "mobileBar", "mobileTotal", "mobileCartLabel", "cartFab", "fabBadge",
    "sheet", "sheetBackdrop",
    "payBackdrop", "payPanel", "payContent",
    "charging", "toast",
    "heldBadge", "heldBackdrop", "heldPanel", "heldList",
    "pendingReceipt"
  ]
  static values = {
    tableSessionId: Number, checkoutUrl: String, diningTableId: Number, heldCartsUrl: String,
    gstRateBp: Number, compositionScheme: Boolean,
    shopName: String, shopAddress: String, shopGstin: String, shopFssai: String, shopFooter: String,
    tableLabel: String
  }

  connect() {
    this.cart = new Map()
    this.render()
    this.resumePendingCheckout()
    this.refreshHeldCount()
    this.updateClock()
    this.clockTimer = setInterval(() => this.updateClock(), 1000)
  }

  disconnect() {
    if (this.retryTimeout) clearTimeout(this.retryTimeout)
    if (this.toastTimeout) clearTimeout(this.toastTimeout)
    if (this.clockTimer) clearInterval(this.clockTimer)
    if (this.cardTimeout) clearTimeout(this.cardTimeout)
  }

  updateClock() {
    if (!this.hasClockTarget) return
    const locale = document.documentElement.lang === "ne" ? "ne-NP" : "en-IN"
    const now = new Date()
    this.clockTarget.textContent = now.toLocaleDateString(locale, { weekday: "short", month: "short", day: "numeric" }) +
      "  " + now.toLocaleTimeString(locale, { hour: "2-digit", minute: "2-digit" })
  }

  // --- cart ---
  add(event) {
    const { menuItemId, menuItemName, menuItemPrice } = event.params
    const existing = this.cart.get(menuItemId)

    this.cart.set(menuItemId, {
      menuItemId,
      name: menuItemName,
      unitPricePaise: menuItemPrice,
      quantity: (existing?.quantity ?? 0) + 1
    })

    this.flashRow(menuItemId)
    this.render()
  }

  updateQty(event) {
    const { menuItemId, delta } = event.params
    const item = this.cart.get(menuItemId)
    if (!item) return

    item.quantity += delta
    if (item.quantity <= 0) this.cart.delete(menuItemId)
    this.render()
  }

  removeItem(event) {
    const { menuItemId } = event.params
    this.cart.delete(menuItemId)
    this.render()
  }

  clearCart() {
    if (this.cart.size === 0) return
    this.cart.clear()
    this.render()
  }

  flashRow(menuItemId) {
    const row = this.itemRowTargets.find((el) => el.dataset.takeawayCheckoutItemId === String(menuItemId))
    if (!row) return
    row.classList.remove("chit-row-flash")
    // eslint-disable-next-line no-unused-expressions
    row.offsetWidth
    row.classList.add("chit-row-flash")
  }

  jumpToCategory(event) {
    const { category } = event.params
    this.categoryTabTargets.forEach((tab) => {
      const active = tab.dataset.takeawayCheckoutCategoryParam === category
      tab.classList.toggle("bg-ink", active)
      tab.classList.toggle("border-ink", active)
      tab.classList.toggle("text-surface", active)
      tab.classList.toggle("bg-card", !active)
      tab.classList.toggle("border-line-2", !active)
      tab.classList.toggle("text-ink-3", !active)
    })

    const section = this.itemListTarget.querySelector(`[data-takeaway-checkout-category-section="${category}"]`)
    section?.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  // --- search ---
  filterItems() {
    const query = this.searchTarget.value.trim().toLowerCase()
    this.searchClearTarget.hidden = query.length === 0

    let anyVisible = false
    this.itemListTarget.querySelectorAll("[data-takeaway-checkout-category-section]").forEach((section) => {
      let sectionHasMatch = false
      section.querySelectorAll('[data-takeaway-checkout-target="itemRow"]').forEach((row) => {
        const name = row.dataset.takeawayCheckoutMenuItemNameParam.toLowerCase()
        const match = !query || name.includes(query)
        row.hidden = !match
        if (match) { sectionHasMatch = true; anyVisible = true }
      })
      section.hidden = !sectionHasMatch
    })

    this.noSearchResultsTarget.hidden = anyVisible
  }

  clearSearch() {
    this.searchTarget.value = ""
    this.filterItems()
    this.searchTarget.focus()
  }

  // --- render ---
  render() {
    const items = Array.from(this.cart.values())
    const count = items.reduce((sum, item) => sum + item.quantity, 0)
    const totalPaise = items.reduce((sum, item) => sum + item.quantity * Number(item.unitPricePaise), 0)
    this.currentTotalPaise = totalPaise

    this.renderRowQuantities()
    this.renderCartLists(items)
    this.renderFooters(count, totalPaise)
    this.renderMobileChrome(count, totalPaise)

    if (count === 0) this.closeCart()
  }

  renderRowQuantities() {
    this.itemRowTargets.forEach((row) => {
      const id = row.dataset.takeawayCheckoutItemId
      const item = this.cart.get(id) || this.cart.get(Number(id))
      const qtyTarget = row.querySelector('[data-takeaway-checkout-target="rowQty"]')
      if (item) {
        qtyTarget.textContent = `× ${item.quantity}`
        qtyTarget.classList.remove("opacity-0", "scale-0")
        qtyTarget.classList.add("opacity-100", "scale-100")
      } else {
        qtyTarget.textContent = ""
        qtyTarget.classList.add("opacity-0", "scale-0")
        qtyTarget.classList.remove("opacity-100", "scale-100")
      }
    })
  }

  renderCartLists(items) {
    const html = items.length ? items.map((item) => this.cartRowHtml(item)).join("") :
      `<div class="flex flex-col items-center justify-center py-14 text-ink-3">
         <div class="text-[32px] mb-2">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M4.00488 16V4H2.00488V2H5.00488C5.55717 2 6.00488 2.44772 6.00488 3V15H18.4433L20.4433 7H8.00488V5H21.7241C22.2764 5 22.7241 5.44772 22.7241 6C22.7241 6.08176 22.7141 6.16322 22.6942 6.24254L20.1942 16.2425C20.083 16.6877 19.683 17 19.2241 17H5.00488C4.4526 17 4.00488 16.5523 4.00488 16ZM6.00488 23C4.90031 23 4.00488 22.1046 4.00488 21C4.00488 19.8954 4.90031 19 6.00488 19C7.10945 19 8.00488 19.8954 8.00488 21C8.00488 22.1046 7.10945 23 6.00488 23ZM18.0049 23C16.9003 23 16.0049 22.1046 16.0049 21C16.0049 19.8954 16.9003 19 18.0049 19C19.1095 19 20.0049 19.8954 20.0049 21C20.0049 22.1046 19.1095 23 18.0049 23Z"></path></svg>
         </div>
         <p class="text-[15px]">${this.t("cart_empty")}</p>
       </div>`

    this.cartListDesktopTarget.innerHTML = html
    this.cartListMobileTarget.innerHTML = html
  }

  cartRowHtml(item) {
    const lineTotal = item.quantity * Number(item.unitPricePaise)
    return `
      <div class="flex items-center gap-3 py-2">
        <div class="flex-1 min-w-0">
          <p class="text-[15px] font-semibold truncate">${item.name}</p>
          <p class="text-[13px] text-ink-3 font-mono">${this.formatInr(item.unitPricePaise)} ${this.t("each")}</p>
        </div>
        <div class="flex items-center gap-1.5 shrink-0">
          <button type="button" data-action="takeaway-checkout#updateQty"
                  data-takeaway-checkout-menu-item-id-param="${item.menuItemId}" data-takeaway-checkout-delta-param="-1"
                  class="w-8 h-8 rounded-key border border-line-2 bg-card text-[16px] font-bold flex items-center justify-center active:bg-key">−</button>
          <span class="w-6 text-center text-[15px] font-bold font-mono">${item.quantity}</span>
          <button type="button" data-action="takeaway-checkout#updateQty"
                  data-takeaway-checkout-menu-item-id-param="${item.menuItemId}" data-takeaway-checkout-delta-param="1"
                  class="w-8 h-8 rounded-key border border-line-2 bg-card text-[16px] font-bold flex items-center justify-center active:bg-key">+</button>
        </div>
        <div class="w-[76px] text-right text-[15px] font-mono font-bold">${this.formatInr(lineTotal)}</div>
      </div>`
  }

  renderFooters(count, totalPaise) {
    const html = this.footerHtml(count, totalPaise)
    this.cartFooterDesktopTarget.innerHTML = html
    this.cartFooterMobileTarget.innerHTML = html
  }

  footerHtml(count, totalPaise) {
    const billing = this.computeBilling(totalPaise)
    const disabled = count === 0
    const taxRows = this.compositionSchemeValue
      ? `<div class="text-[12px] italic">${this.t("composition_declaration")}</div>`
      : `<div class="flex justify-between"><span>${this.t("cgst")}</span><span class="font-mono">${this.formatInr(billing.cgstPaise)}</span></div>
         <div class="flex justify-between"><span>${this.t("sgst")}</span><span class="font-mono">${this.formatInr(billing.sgstPaise)}</span></div>`

    return `
      <div class="flex flex-col gap-1 mb-3 text-[14px] text-ink-3">
        <div class="flex justify-between"><span>${this.t("subtotal")}</span><span class="font-mono">${this.formatInr(billing.taxablePaise)}</span></div>
        ${taxRows}
        <div class="flex justify-between text-[17px] font-bold text-ink pt-1.5 border-t border-line"><span>${this.t("total")}</span><span class="font-mono">${this.formatInr(billing.totalPaise)}</span></div>
      </div>
      <button type="button" data-action="takeaway-checkout#openPayment" ${disabled ? "disabled" : ""}
              class="w-full min-h-[56px] rounded-tile text-[16px] font-bold transition-colors
                     ${disabled ? "bg-key-2 text-ink-4" : "bg-go text-surface active:bg-go-700"}">
        ${disabled ? this.t("add_items_to_pay") : `${this.t("pay")}  ${this.formatInr(billing.totalPaise)}`}
      </button>`
  }

  renderMobileChrome(count, totalPaise) {
    const billing = this.computeBilling(totalPaise)

    this.mobileBarTarget.hidden = count === 0
    this.cartFabTarget.hidden = count === 0
    if (count > 0) {
      this.mobileTotalTarget.textContent = this.formatInr(billing.totalPaise)
      this.mobileCartLabelTarget.textContent = `${this.t("view_cart")} (${count})`
      this.fabBadgeTarget.hidden = false
      this.fabBadgeTarget.textContent = count
    }
  }

  formatInr(paise) {
    const rupees = paise / 100
    return `₹${rupees.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }

  // Mirrors Billing.compute exactly (app/models/billing.rb) so the on-screen
  // preview matches what the server actually charges once the ticket is
  // submitted — CGST+SGST split on the half rate, round-off to the nearest
  // rupee, zero tax under composition scheme (CLAUDE.md invariant #7).
  computeBilling(taxablePaise) {
    if (this.compositionSchemeValue) {
      return { taxablePaise, cgstPaise: 0, sgstPaise: 0, totalPaise: taxablePaise }
    }

    const halfRateBp = this.gstRateBpValue / 2
    const cgstPaise = Math.round((taxablePaise * halfRateBp) / 10000)
    const sgstPaise = cgstPaise
    const preRoundTotal = taxablePaise + cgstPaise + sgstPaise
    const totalPaise = Math.round(preRoundTotal / 100) * 100

    return { taxablePaise, cgstPaise, sgstPaise, totalPaise }
  }

  // --- mobile cart sheet ---
  openCart() {
    this.sheetBackdropTarget.hidden = false
    this.sheetTarget.hidden = false
    requestAnimationFrame(() => {
      this.sheetBackdropTarget.classList.remove("opacity-0")
      this.sheetBackdropTarget.classList.add("pointer-events-auto")
      this.sheetTarget.classList.remove("translate-y-full")
    })
  }

  closeCart() {
    this.sheetTarget.classList.add("translate-y-full")
    this.sheetBackdropTarget.classList.add("opacity-0")
    this.sheetBackdropTarget.classList.remove("pointer-events-auto")
    setTimeout(() => {
      this.sheetTarget.hidden = true
      this.sheetBackdropTarget.hidden = true
    }, 300)
  }

  // --- payment modal ---
  openPayment() {
    if (this.cart.size === 0) return
    this.closeCart()

    const billing = this.computeBilling(this.currentTotalPaise)
    this.payAmountDue = billing.totalPaise

    this.payContentTarget.innerHTML = `
      <div class="bg-shell rounded-ctl p-4 mb-4 text-center">
        <p class="text-[12px] text-ink-3 font-semibold uppercase tracking-wide mb-1">${this.t("amount_due")}</p>
        <p class="text-[32px] font-mono font-bold text-go">${this.formatInr(billing.totalPaise)}</p>
      </div>
      <p class="text-[12px] text-ink-3 font-semibold uppercase tracking-wide mb-2">${this.t("select_method")}</p>
      <div class="grid grid-cols-2 gap-2.5 mb-2">
        <button type="button" data-action="takeaway-checkout#selectPayMethod" data-takeaway-checkout-method-param="cash"
                class="flex flex-col items-center gap-1.5 p-4 rounded-ctl border-2 border-line-2 bg-shell active:border-go">
          <span class="text-[24px]">💵</span><span class="text-[14px] font-bold">${this.t("pay_method_cash")}</span>
        </button>
        <button type="button" data-action="takeaway-checkout#selectPayMethod" data-takeaway-checkout-method-param="upi"
                class="flex flex-col items-center gap-1.5 p-4 rounded-ctl border-2 border-line-2 bg-shell active:border-go">
          <span class="text-[24px]">📱</span><span class="text-[14px] font-bold">${this.t("pay_method_upi")}</span>
        </button>
        <button type="button" data-action="takeaway-checkout#selectPayMethod" data-takeaway-checkout-method-param="card"
                class="flex flex-col items-center gap-1.5 p-4 rounded-ctl border-2 border-line-2 bg-shell active:border-go">
          <span class="text-[24px]">💳</span><span class="text-[14px] font-bold">${this.t("pay_method_card")}</span>
        </button>
        <button type="button" data-action="takeaway-checkout#selectPayMethod" data-takeaway-checkout-method-param="other"
                class="flex flex-col items-center gap-1.5 p-4 rounded-ctl border-2 border-line-2 bg-shell active:border-go">
          <span class="text-[24px]">⋯</span><span class="text-[14px] font-bold">${this.t("pay_method_other")}</span>
        </button>
      </div>
      <div data-takeaway-checkout-target="payDetail"></div>`

    this.payBackdropTarget.hidden = false
    this.payPanelTarget.hidden = false
    requestAnimationFrame(() => {
      this.payBackdropTarget.classList.remove("opacity-0")
      this.payBackdropTarget.classList.add("pointer-events-auto")
      this.payPanelTarget.classList.remove("translate-y-full")
    })
  }

  closePayment() {
    if (this.cardTimeout) clearTimeout(this.cardTimeout)
    this.payPanelTarget.classList.add("translate-y-full")
    this.payBackdropTarget.classList.add("opacity-0")
    this.payBackdropTarget.classList.remove("pointer-events-auto")
    setTimeout(() => {
      this.payPanelTarget.hidden = true
      this.payBackdropTarget.hidden = true
    }, 300)
  }

  selectPayMethod(event) {
    const method = event.params.method
    this.payPanelTarget.querySelectorAll("[data-takeaway-checkout-method-param]").forEach((btn) => {
      btn.classList.toggle("border-go", btn.dataset.takeawayCheckoutMethodParam === method)
    })

    const detail = this.payPanelTarget.querySelector('[data-takeaway-checkout-target="payDetail"]')

    if (method === "cash") {
      detail.innerHTML = this.cashDetailHtml()
    } else if (method === "card") {
      detail.innerHTML = `
        <div class="mt-4 flex flex-col items-center py-6">
          <div class="w-9 h-9 border-[3px] border-line-2 border-t-go rounded-full animate-spin mb-3"></div>
          <p class="text-[14px] text-ink-3" data-card-status>${this.t("card_prompt")}</p>
        </div>`
      this.cardTimeout = setTimeout(() => {
        const spinner = detail.querySelector(".animate-spin")
        const status = detail.querySelector("[data-card-status]")
        if (!spinner) return
        spinner.outerHTML = `<span class="text-go text-[36px] mb-2">✓</span>`
        status.textContent = this.t("card_approved")
        status.classList.add("text-go")
        this.cardTimeout = setTimeout(() => this.completeCheckout(method), 500)
      }, 1200)
    } else {
      detail.innerHTML = `
        <button type="button" data-action="takeaway-checkout#confirmNonCash" data-takeaway-checkout-method-param="${method}"
                class="w-full min-h-[56px] mt-4 rounded-tile text-[16px] font-bold bg-go text-surface active:bg-go-700">
          ${this.t("confirm_payment")}
        </button>`
    }
  }

  cashDetailHtml() {
    const due = this.payAmountDue
    const amounts = this.cashQuickAmounts(due)
    return `
      <div class="mt-4">
        <p class="text-[12px] text-ink-3 font-semibold uppercase tracking-wide mb-2">${this.t("cash_received")}</p>
        <div class="grid grid-cols-4 gap-2 mb-3">
          ${amounts.map((a) => `<button type="button" data-action="takeaway-checkout#setCashAmount" data-takeaway-checkout-amount-param="${a}"
              class="cash-amt-btn min-h-[48px] rounded-key border-2 border-line-2 font-mono font-bold text-[14px]">${this.formatInr(a)}</button>`).join("")}
        </div>
        <input type="text" inputmode="numeric" placeholder="${this.t("other_amount")}" data-action="input->takeaway-checkout#typeCashAmount"
               class="w-full min-h-[48px] px-3 rounded-ctl border-2 border-line-2 font-mono text-[16px] mb-3">
        <div data-change-display class="mb-1"></div>
        <button type="button" data-action="takeaway-checkout#confirmCash" data-confirm-cash disabled
                class="w-full min-h-[56px] mt-2 rounded-tile text-[16px] font-bold bg-go text-surface disabled:bg-key-2 disabled:text-ink-4">
          ${this.t("confirm_payment")}
        </button>
      </div>`
  }

  cashQuickAmounts(duePaise) {
    const exact = Math.ceil(duePaise / 100) * 100
    const notes = [50000, 100000, 200000, 500000] // ₹500 / ₹1000 / ₹2000 / ₹5000 in paise
    const amounts = [exact]
    for (const note of notes) {
      if (note >= exact && !amounts.includes(note)) amounts.push(note)
      if (amounts.length >= 4) break
    }
    return amounts.sort((a, b) => a - b).slice(0, 4)
  }

  setCashAmount(event) {
    this.applyCashAmount(Number(event.params.amount))
  }

  typeCashAmount(event) {
    const rupees = parseFloat(event.currentTarget.value) || 0
    this.applyCashAmount(Math.round(rupees * 100))
  }

  applyCashAmount(receivedPaise) {
    this.cashReceivedPaise = receivedPaise
    const due = this.payAmountDue
    const change = receivedPaise - due

    this.payPanelTarget.querySelectorAll(".cash-amt-btn").forEach((btn) => {
      btn.classList.toggle("border-go", Number(btn.dataset.takeawayCheckoutAmountParam) === receivedPaise)
    })

    const display = this.payPanelTarget.querySelector("[data-change-display]")
    const confirmBtn = this.payPanelTarget.querySelector("[data-confirm-cash]")
    if (!display || !confirmBtn) return

    if (receivedPaise <= 0) {
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

  confirmCash(event) {
    if (!this.cashReceivedPaise || this.cashReceivedPaise < this.payAmountDue) return
    this.completeCheckout("cash", event.currentTarget)
  }

  confirmNonCash(event) {
    this.completeCheckout(event.params.method, event.currentTarget)
  }

  async completeCheckout(method, button) {
    if (button) this.stampButton(button)

    const items = Array.from(this.cart.values())

    const entry = await enqueue({
      kind: "takeaway_checkout",
      payload: {
        table_session_id: this.tableSessionIdValue,
        method,
        // name/unit_price_paise ride along for the offline receipt only
        // (see receiptPayloadFrom below) — Sync::Handlers::TakeawayCheckout
        // only reads menu_item_id/quantity/notes and ignores the rest, but
        // this is the one place the display info survives a page reload,
        // since the live cart is cleared right after this and IndexedDB
        // is the only thing that persists across it.
        items: items.map((item) => ({
          menu_item_id: item.menuItemId, quantity: item.quantity,
          name: item.name, unit_price_paise: item.unitPricePaise
        })),
        client_token: crypto.randomUUID()
      }
    })

    this.cart.clear()
    this.render()
    setTimeout(() => this.closePayment(), method === "cash" || method === "other" ? 250 : 0)
    this.attemptCheckout(entry.id, this.receiptPayloadFrom(entry.payload))
  }

  receiptPayloadFrom(payload) {
    return {
      items: payload.items.map((item) => ({
        name: item.name, unitPricePaise: item.unit_price_paise, quantity: item.quantity
      }))
    }
  }

  stampButton(button) {
    button.classList.add("stamp-btn", "relative")
    button.classList.remove("stamp-punch")
    // eslint-disable-next-line no-unused-expressions
    button.offsetWidth
    button.classList.add("stamp-punch")
  }

  async resumePendingCheckout() {
    const entries = await allOutboxEntries()
    const pendingEntry = entries.find((entry) => entry.kind === "takeaway_checkout" && entry.status !== "applied")
    if (!pendingEntry) return

    // A reload mid-retry (e.g. the cashier checking the screen) would
    // otherwise flash the empty cart before the first retry lands —
    // show the pending receipt immediately since payment was already
    // confirmed on-screen once and shouldn't look "undone" on refresh.
    const receiptPayload = this.receiptPayloadFrom(pendingEntry.payload)
    this.showPendingReceipt(receiptPayload)
    this.attemptCheckout(pendingEntry.id, receiptPayload, true)
  }

  async attemptCheckout(entryId, receiptPayload, isRetry = false) {
    this.chargingTarget.hidden = false
    this.chargingTarget.querySelector("[data-charging-label]").textContent =
      this.t(isRetry ? "charging_offline" : "charging")

    await drain()
    const status = await entryStatus(entryId)

    if (status === "applied") {
      window.location.reload()
      return
    }

    if (status === "rejected") {
      this.chargingTarget.hidden = true
      this.showToast(this.t("checkout_failed"))
      return
    }

    this.showPendingReceipt(receiptPayload)
    this.scheduleRetry(entryId, receiptPayload)
  }

  scheduleRetry(entryId, receiptPayload) {
    this.retryTimeout = setTimeout(() => this.attemptCheckout(entryId, receiptPayload, true), 5000)
  }

  // --- offline pending receipt ---
  // Built entirely from the outbox entry's own payload (see
  // completeCheckout/receiptPayloadFrom) — no invoice exists yet, since the
  // server hasn't accepted the ticket+payment. Same layout, math, and
  // buttons as the real post-payment receipt (show.html.erb's server-
  // rendered version) so there is no visible difference to staff or
  // customers; once the queued request succeeds, attemptCheckout reloads
  // the page and the real, server-issued receipt takes over.
  showPendingReceipt(payload) {
    const billing = this.computeBilling(payload.items.reduce((sum, item) => sum + item.quantity * Number(item.unitPricePaise), 0))
    const now = new Date()
    const dateStr = `${String(now.getDate()).padStart(2, "0")}-${now.toLocaleString("en", { month: "short" })}-${now.getFullYear()} ${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`

    const itemRows = payload.items.map((item) => `
      <div class="flex justify-between gap-3 text-[13px] py-0.5">
        <span class="flex-1">${item.quantity} x ${item.name}</span>
        <span>${this.formatInr(item.quantity * Number(item.unitPricePaise))}</span>
      </div>`).join("")

    const taxRows = this.compositionSchemeValue
      ? `<p class="text-[12px] mt-1">${this.t("composition_declaration")}</p>`
      : `<div class="flex justify-between text-[13px]"><span>${this.t("cgst")}</span><span>${this.formatInr(billing.cgstPaise)}</span></div>
         <div class="flex justify-between text-[13px]"><span>${this.t("sgst")}</span><span>${this.formatInr(billing.sgstPaise)}</span></div>`

    this.pendingReceiptTarget.innerHTML = `
      <header class="flex items-center gap-3 px-4 pt-[max(1rem,env(safe-area-inset-top))] pb-3">
        <h1 class="text-[19px] font-bold flex-1">${this.tableLabelValue}</h1>
      </header>
      <div class="p-4 flex flex-col items-center gap-4 w-full">
        <div class="receipt-print-root">
          <div class="receipt-preview rounded-ctl border border-line-2 shadow-sm p-4">
            <div class="text-center">
              <p class="font-bold text-[16px]">${this.shopNameValue}</p>
              ${this.shopAddressValue ? `<p class="text-[12px]">${this.shopAddressValue}</p>` : ""}
              ${this.shopGstinValue ? `<p class="text-[12px]">GSTIN: ${this.shopGstinValue}</p>` : ""}
              ${this.shopFssaiValue ? `<p class="text-[12px]">FSSAI: ${this.shopFssaiValue}</p>` : ""}
            </div>
            <div class="receipt-rule my-2"></div>
            <p class="text-[13px]">${dateStr}</p>
            <p class="text-[13px]">${this.tableLabelValue}</p>
            <div class="receipt-rule my-2"></div>
            ${itemRows}
            <div class="receipt-rule my-2"></div>
            <div class="flex justify-between text-[13px]"><span>${this.t("subtotal")}</span><span>${this.formatInr(billing.taxablePaise)}</span></div>
            ${taxRows}
            <div class="receipt-rule my-2"></div>
            <div class="flex justify-between text-[16px] font-bold"><span>${this.t("total")}</span><span>${this.formatInr(billing.totalPaise)}</span></div>
            <div class="receipt-rule my-2"></div>
            ${this.shopFooterValue ? `<p class="text-center text-[12px] mt-1">${this.shopFooterValue}</p>` : ""}
          </div>
        </div>
        <div class="w-full max-w-[340px] flex flex-col gap-2.5">
          <button type="button" onclick="window.print()"
                  class="w-full min-h-[64px] rounded-tile text-[18px] font-bold bg-go text-surface active:bg-go-700">
            ${this.t("print_receipt")}
          </button>
          <a href="/takeaway"
             class="text-center min-h-[56px] flex items-center justify-center rounded-tile text-[15px] font-bold bg-key text-ink active:bg-key-2">
            ${this.t("new_order")}
          </a>
        </div>
      </div>`

    this.pendingReceiptTarget.hidden = false
  }

  // --- hold / held orders ---
  // Held carts are server-side (HeldCart), not TableSession/Ticket — nothing
  // reaches the kitchen or reserves an invoice number until restored and
  // charged. This is what lets a hold survive a reload or a device switch.
  async hold() {
    const items = Array.from(this.cart.values())
    if (items.length === 0) {
      this.showToast(this.t("hold_empty"))
      return
    }

    try {
      const response = await fetch(this.heldCartsUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          items: items.map((item) => ({
            menu_item_id: item.menuItemId,
            name_snapshot: item.name,
            unit_price_paise: item.unitPricePaise,
            quantity: item.quantity
          }))
        })
      })
      if (!response.ok) throw new Error(`hold failed: ${response.status}`)

      this.cart.clear()
      this.render()
      this.refreshHeldCount()
      this.showToast(this.t("cart_held"))
    } catch {
      this.showToast(this.t("hold_empty"))
    }
  }

  async refreshHeldCount() {
    const carts = await this.fetchHeldCarts()
    if (!carts) return
    this.heldBadgeTarget.hidden = carts.length === 0
    this.heldBadgeTarget.textContent = carts.length
  }

  async fetchHeldCarts() {
    try {
      const response = await fetch(this.heldCartsUrlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return null
      return await response.json()
    } catch {
      return null
    }
  }

  async showHeld() {
    const carts = await this.fetchHeldCarts()
    this.renderHeldList(carts || [])

    this.heldBackdropTarget.hidden = false
    this.heldPanelTarget.hidden = false
    requestAnimationFrame(() => {
      this.heldBackdropTarget.classList.remove("opacity-0")
      this.heldBackdropTarget.classList.add("pointer-events-auto")
      this.heldPanelTarget.classList.remove("translate-y-full")
    })
  }

  closeHeld() {
    this.heldPanelTarget.classList.add("translate-y-full")
    this.heldBackdropTarget.classList.add("opacity-0")
    this.heldBackdropTarget.classList.remove("pointer-events-auto")
    setTimeout(() => {
      this.heldPanelTarget.hidden = true
      this.heldBackdropTarget.hidden = true
    }, 300)
  }

  renderHeldList(carts) {
    if (carts.length === 0) {
      this.heldListTarget.innerHTML = `<p class="py-10 text-center text-[16px] text-ink-3">${this.t("no_held_orders")}</p>`
      return
    }

    this.heldListTarget.innerHTML = carts.map((cart) => {
      const time = new Date(cart.held_at).toLocaleTimeString(document.documentElement.lang === "ne" ? "ne-NP" : "en-IN", { hour: "2-digit", minute: "2-digit" })
      return `
        <div class="flex items-center gap-3 p-3.5 rounded-tile bg-card border-l-[6px] border-warn border-y border-r border-line">
          <div class="flex-1 min-w-0">
            <div class="text-[16px] font-semibold">${this.pluralizeCount(cart.item_count)}</div>
            <div class="text-[13px] text-ink-3">${this.t("held_at").replace("%{time}", time)}</div>
          </div>
          <div class="font-mono font-bold text-[17px]">${this.formatInr(cart.total_paise)}</div>
          <button type="button" data-action="takeaway-checkout#restoreHeld" data-held-cart-id="${cart.id}"
                  class="shrink-0 min-h-[44px] px-4 rounded-key bg-go text-surface text-[15px] font-bold active:bg-go-700">
            ${this.t("restore")}
          </button>
          <button type="button" data-action="takeaway-checkout#deleteHeld" data-held-cart-id="${cart.id}"
                  class="shrink-0 min-h-[44px] w-[44px] rounded-key border-2 border-line-2 text-ink-3 text-[15px] font-bold">✕</button>
        </div>`
    }).join("")
  }

  async restoreHeld(event) {
    const heldCartId = event.currentTarget.dataset.heldCartId
    const carts = await this.fetchHeldCarts()
    const cart = (carts || []).find((c) => String(c.id) === heldCartId)
    if (!cart) return

    if (this.cart.size > 0) this.cart.clear()
    cart.items.forEach((item) => {
      this.cart.set(item.menu_item_id, {
        menuItemId: item.menu_item_id,
        name: item.name_snapshot,
        unitPricePaise: item.unit_price_paise,
        quantity: item.quantity
      })
    })

    await this.deleteHeldCart(cart.id)
    this.render()
    this.refreshHeldCount()
    this.closeHeld()
    this.showToast(this.t("cart_restored"))
  }

  async deleteHeld(event) {
    const heldCartId = event.currentTarget.dataset.heldCartId
    await this.deleteHeldCart(heldCartId)
    this.showHeld()
    this.refreshHeldCount()
  }

  async deleteHeldCart(id) {
    try {
      await fetch(`/held_carts/${id}`, {
        method: "DELETE",
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content }
      })
    } catch {
      // best-effort — a stray held cart just sits in the list, no data loss
    }
  }

  showToast(message) {
    this.toastTarget.textContent = message
    this.toastTarget.hidden = false
    requestAnimationFrame(() => this.toastTarget.classList.remove("opacity-0"))

    if (this.toastTimeout) clearTimeout(this.toastTimeout)
    this.toastTimeout = setTimeout(() => {
      this.toastTarget.classList.add("opacity-0")
      setTimeout(() => { this.toastTarget.hidden = true }, 200)
    }, 2500)
  }

  pluralizeCount(count) {
    const locale = document.documentElement.lang
    if (locale === "ne") return `${this.toDevanagariDigits(count)} वटा`
    return count === 1 ? "1 item" : `${count} items`
  }

  toDevanagariDigits(n) {
    const map = "०१२३४५६७८९"
    return String(n).replace(/\d/g, (d) => map[d])
  }

  t(key) {
    const locale = document.documentElement.lang
    const strings = {
      hold_empty: { en: "Cart is empty", ne: "कार्ट खाली छ" },
      cart_held: { en: "Order held", ne: "अर्डर पर्खाइयो" },
      cart_restored: { en: "Order restored", ne: "अर्डर फिर्ता आयो" },
      no_held_orders: { en: "No held orders", ne: "कुनै पर्खिरहेको अर्डर छैन" },
      held_at: { en: "Held at %{time}", ne: "%{time} मा राखियो" },
      restore: { en: "Restore", ne: "फिर्ता ल्याउनुहोस्" },
      cart_empty: { en: "Tap items to add", ne: "थप्न वस्तुमा थिच्नुहोस्" },
      view_cart: { en: "View cart", ne: "कार्ट हेर्नुहोस्" },
      pay: { en: "Pay", ne: "तिर्नुहोस्" },
      add_items_to_pay: { en: "Add items to pay", ne: "तिर्न वस्तु थप्नुहोस्" },
      amount_due: { en: "Amount due", ne: "तिर्नुपर्ने रकम" },
      select_method: { en: "Select method", ne: "माध्यम छान्नुहोस्" },
      pay_method_cash: { en: "Cash", ne: "नगद" },
      pay_method_upi: { en: "UPI", ne: "UPI" },
      pay_method_card: { en: "Card", ne: "कार्ड" },
      pay_method_other: { en: "Other", ne: "अन्य" },
      cash_received: { en: "Cash received", ne: "प्राप्त नगद" },
      other_amount: { en: "Other amount", ne: "अर्को रकम" },
      change_due: { en: "Change due", ne: "फिर्ता रकम" },
      insufficient_amount: { en: "Insufficient amount", ne: "रकम अपुग छ" },
      charging: { en: "Charging...", ne: "भुक्तानी हुँदैछ..." },
      charging_offline: { en: "Waiting for internet — will send automatically", ne: "इन्टरनेट पर्खँदै — पुनः प्रयास हुँदैछ" },
      checkout_failed: { en: "Checkout could not be completed — ask an admin", ne: "चेकआउट पूरा हुन सकेन — admin लाई सोध्नुहोस्" },
      print_receipt: { en: "Print receipt", ne: "रसिद छाप्नुहोस्" },
      new_order: { en: "Start new order", ne: "नयाँ अर्डर सुरु गर्नुहोस्" },
      confirm_payment: { en: "Confirm payment", ne: "भुक्तानी पक्का गर्नुहोस्" },
      card_prompt: { en: "Tap or insert card...", ne: "कार्ड ट्याप वा इन्सर्ट गर्नुहोस्..." },
      card_approved: { en: "Payment approved", ne: "भुक्तानी स्वीकृत भयो" },
      subtotal: { en: "Subtotal", ne: "मूल्य" },
      cgst: { en: "CGST", ne: "मू.अ.कर (CGST)" },
      sgst: { en: "SGST", ne: "मू.अ.कर (SGST)" },
      composition_declaration: { en: "Composition taxable person, not eligible to collect tax on supplies", ne: "Composition taxable person, not eligible to collect tax on supplies" },
      total: { en: "Total", ne: "जम्मा" },
      each: { en: "each", ne: "प्रति" }
    }
    return strings[key][locale] || strings[key].en
  }
}
