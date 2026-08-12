import { Controller } from "@hotwired/stimulus"

// Counter checkout: build a cart, tap Cash/UPI/Card once. That single
// request submits the ticket (which fires to the kitchen immediately via
// Ticket's broadcasts_refreshes_to — see TakeawayCheckoutsController),
// pays the exact total in full, issues the invoice, and queues the print
// job. Idempotent the same way order-cart is: a client_token is generated
// once and persisted before the request so a retry after a network blip
// never double-submits or double-charges (see CLAUDE.md invariant #2).
export default class extends Controller {
  static targets = [
    "itemRow", "rowQty", "rowAccent", "categoryTab", "itemList",
    "chitBar", "chitSummary", "chitTotal", "emptyFooter",
    "sheet", "sheetBackdrop", "sheetTotal", "sheetChargeCash", "sheetChargeUpi", "sheetChargeCard",
    "undoToast", "undoText", "charging"
  ]
  static values = { tableSessionId: Number, checkoutUrl: String }

  connect() {
    this.cart = new Map()
    this.render()
    this.resumePendingCheckout()
  }

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

  remove(event) {
    const { menuItemId } = event.params
    const removed = this.cart.get(menuItemId)
    this.cart.delete(menuItemId)
    this.render()
    if (removed) this.showUndo(removed)
  }

  showUndo(removedItem) {
    this.lastRemoved = removedItem
    this.undoTextTarget.textContent = this.removedItemText(removedItem.name)
    this.undoToastTarget.hidden = false

    if (this.undoTimeout) clearTimeout(this.undoTimeout)
    this.undoTimeout = setTimeout(() => this.hideUndo(), 5000)
  }

  hideUndo() {
    this.undoToastTarget.hidden = true
    this.lastRemoved = null
  }

  undoRemove() {
    if (!this.lastRemoved) return
    this.cart.set(this.lastRemoved.menuItemId, this.lastRemoved)
    if (this.undoTimeout) clearTimeout(this.undoTimeout)
    this.hideUndo()
    this.render()
  }

  removedItemText(name) {
    const locale = document.documentElement.lang
    return locale === "ne" ? `${name} हटाइयो` : `Removed ${name}`
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
      tab.classList.toggle("text-surface", active)
      tab.classList.toggle("bg-key", !active)
      tab.classList.toggle("text-ink", !active)
    })

    const section = this.itemListTarget.querySelector(`[data-takeaway-checkout-category-section="${category}"]`)
    section?.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  toggleSheet() {
    const isOpen = !this.sheetTarget.hidden
    if (isOpen) {
      this.closeSheet()
    } else {
      this.openSheet()
    }
  }

  openSheet() {
    this.sheetBackdropTarget.hidden = false
    this.sheetTarget.hidden = false
    requestAnimationFrame(() => {
      this.sheetBackdropTarget.classList.remove("opacity-0")
      this.sheetTarget.classList.remove("translate-y-full")
    })
  }

  closeSheet() {
    this.sheetTarget.classList.add("translate-y-full")
    this.sheetBackdropTarget.classList.add("opacity-0")
    setTimeout(() => {
      this.sheetTarget.hidden = true
      this.sheetBackdropTarget.hidden = true
    }, 200)
  }

  render() {
    const items = Array.from(this.cart.values())
    const count = items.reduce((sum, item) => sum + item.quantity, 0)
    const totalPaise = items.reduce((sum, item) => sum + item.quantity * Number(item.unitPricePaise), 0)

    const hasItems = items.length > 0;
    [this.sheetChargeCashTarget, this.sheetChargeUpiTarget, this.sheetChargeCardTarget].forEach((button) => {
      button.disabled = !hasItems
    })
    this.renderRowQuantities()
    this.renderChit(count, totalPaise)

    if (!hasItems) this.closeSheet()
  }

  renderRowQuantities() {
    this.itemRowTargets.forEach((row) => {
      const id = row.dataset.takeawayCheckoutItemId
      const item = this.cart.get(id) || this.cart.get(Number(id))
      const qtyTarget = row.querySelector('[data-takeaway-checkout-target="rowQty"]')
      const accent = row.querySelector('[data-takeaway-checkout-target="rowAccent"]')
      if (item) {
        qtyTarget.textContent = `× ${item.quantity}`
        accent.classList.remove("w-1", "bg-line-2")
        accent.classList.add("w-1.5", "bg-go")
      } else {
        qtyTarget.textContent = ""
        accent.classList.remove("w-1.5", "bg-go")
        accent.classList.add("w-1", "bg-line-2")
      }
    })
  }

  renderChit(count, totalPaise) {
    const hasItems = count > 0
    this.chitBarTarget.hidden = !hasItems
    this.emptyFooterTarget.hidden = hasItems
    this.currentTotalPaise = totalPaise
    if (!hasItems) return

    this.chitSummaryTarget.textContent = this.pluralize(count)
    const formatted = this.formatInr(totalPaise)
    this.chitTotalTarget.textContent = formatted
    this.sheetTotalTarget.textContent = formatted;
    [this.sheetChargeCashTarget, this.sheetChargeUpiTarget, this.sheetChargeCardTarget].forEach((button) => {
      button.querySelector("[data-amount]").textContent = formatted
    })
  }

  pluralize(count) {
    const locale = document.documentElement.lang
    if (locale === "ne") return `${this.toDevanagariDigits(count)} वटा`
    return count === 1 ? "1 item" : `${count} items`
  }

  toDevanagariDigits(n) {
    const map = "०१२३४५६७८९"
    return String(n).replace(/\d/g, (d) => map[d])
  }

  formatInr(paise) {
    const rupees = paise / 100
    return `₹${rupees.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }

  charge(event) {
    const items = Array.from(this.cart.values())
    if (items.length === 0) return

    const { method } = event.params
    const clientToken = crypto.randomUUID()
    const payload = { clientToken, tableSessionId: this.tableSessionIdValue, method, items }

    this.persistPending(payload)
    this.cart.clear()
    if (this.undoTimeout) clearTimeout(this.undoTimeout)
    this.hideUndo()
    this.render()
    this.closeSheet()
    this.attemptCheckout(payload)
  }

  resumePendingCheckout() {
    const pending = this.readPending()
    if (pending) this.attemptCheckout(pending)
  }

  async attemptCheckout(payload) {
    this.chargingTarget.hidden = false

    try {
      const response = await fetch(this.checkoutUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          client_token: payload.clientToken,
          table_session_id: payload.tableSessionId,
          method: payload.method,
          items: payload.items.map((item) => ({
            menu_item_id: item.menuItemId,
            quantity: item.quantity
          }))
        })
      })

      if (!response.ok) throw new Error(`checkout failed: ${response.status}`)

      this.clearPending(payload.clientToken)
      window.location.reload()
    } catch {
      this.scheduleRetry(payload)
    }
  }

  scheduleRetry(payload) {
    this.retryTimeout = setTimeout(() => this.attemptCheckout(payload), 5000)
  }

  disconnect() {
    if (this.retryTimeout) clearTimeout(this.retryTimeout)
    if (this.undoTimeout) clearTimeout(this.undoTimeout)
  }

  storageKey() {
    return `pos:pending-takeaway-checkout:${this.tableSessionIdValue}`
  }

  persistPending(payload) {
    localStorage.setItem(this.storageKey(), JSON.stringify(payload))
  }

  readPending() {
    try {
      const raw = localStorage.getItem(this.storageKey())
      return raw ? JSON.parse(raw) : null
    } catch {
      return null
    }
  }

  clearPending(clientToken) {
    const pending = this.readPending()
    if (pending?.clientToken === clientToken) localStorage.removeItem(this.storageKey())
  }
}
