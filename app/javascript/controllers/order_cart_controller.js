import { Controller } from "@hotwired/stimulus"

// Builds a cart of menu items client-side, then submits it as one ticket.
// Submission is idempotent: a client_token is generated once per ticket,
// persisted to localStorage before the request, and retried on failure —
// see CLAUDE.md invariant #2 and ARCHITECTURE.md §5. Do not remove the
// localStorage persistence; it is what survives a page refresh mid-retry.
export default class extends Controller {
  static targets = [
    "list", "submit", "pendingBanner", "pendingCount",
    "itemRow", "rowQty", "categoryTab", "itemList",
    "chitBar", "chitSummary", "chitTotal", "emptyFooter",
    "sheet", "sheetBackdrop", "sheetTotal",
    "undoToast", "undoText",
    "billPanel", "billBackdrop", "billUnsentWarning"
  ]
  static values = { tableSessionId: Number, submitUrl: String }

  connect() {
    this.cart = new Map()
    this.render()
    this.resumePendingSubmission()
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
    const row = this.itemRowTargets.find((el) => el.dataset.orderCartItemId === String(menuItemId))
    if (!row) return
    row.classList.remove("chit-row-flash")
    // eslint-disable-next-line no-unused-expressions
    row.offsetWidth // restart animation
    row.classList.add("chit-row-flash")
  }

  jumpToCategory(event) {
    const { category } = event.params
    this.categoryTabTargets.forEach((tab) => {
      const active = tab.dataset.orderCartCategoryParam === category
      tab.classList.toggle("bg-ink", active)
      tab.classList.toggle("text-surface", active)
      tab.classList.toggle("bg-key", !active)
      tab.classList.toggle("text-ink", !active)
    })

    const section = this.itemListTarget.querySelector(`[data-order-cart-category-section="${category}"]`)
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

  // Bill panel: same table_session, no page nav — so a waiter can check
  // out and keep adding items without losing their place. Loads its
  // content lazily on first open via the "bill_panel_content" Turbo Frame;
  // void/discount/payment forms inside it submit and swap back into the
  // same frame automatically (their controllers redirect to bills#show).
  openBill(event) {
    const cartCount = this.cart.size
    this.billUnsentWarningTarget.hidden = cartCount === 0

    if (!this.billFrameLoaded) {
      const frame = this.billPanelTarget.querySelector("turbo-frame#bill_panel_content")
      frame.src = event.params.billUrl
      this.billFrameLoaded = true
    }

    this.billBackdropTarget.hidden = false
    this.billPanelTarget.hidden = false
    requestAnimationFrame(() => {
      this.billBackdropTarget.classList.remove("opacity-0")
      this.billPanelTarget.classList.remove("translate-y-full")
    })
  }

  closeBill() {
    this.billPanelTarget.classList.add("translate-y-full")
    this.billBackdropTarget.classList.add("opacity-0")
    setTimeout(() => {
      this.billPanelTarget.hidden = true
      this.billBackdropTarget.hidden = true
    }, 200)
  }

  render() {
    const items = Array.from(this.cart.values())
    const count = items.reduce((sum, item) => sum + item.quantity, 0)
    const totalPaise = items.reduce((sum, item) => sum + item.quantity * Number(item.unitPricePaise), 0)

    this.submitTarget.disabled = items.length === 0
    this.renderRowQuantities()
    this.renderChit(count, totalPaise)
    this.listTarget.replaceChildren(...items.map((item) => this.buildLineItem(item)))

    if (items.length === 0) this.closeSheet()
  }

  renderRowQuantities() {
    this.itemRowTargets.forEach((row) => {
      const id = row.dataset.orderCartItemId
      const item = this.cart.get(id) || this.cart.get(Number(id))
      const qtyTarget = row.querySelector('[data-order-cart-target="rowQty"]')
      if (item) {
        qtyTarget.textContent = `× ${item.quantity}`
        qtyTarget.classList.remove("opacity-0", "scale-75")
        qtyTarget.classList.add("opacity-100", "scale-100")
        row.classList.add("border-go", "bg-go-50")
        row.classList.remove("border-line")
      } else {
        qtyTarget.textContent = ""
        qtyTarget.classList.add("opacity-0", "scale-75")
        qtyTarget.classList.remove("opacity-100", "scale-100")
        row.classList.remove("border-go", "bg-go-50")
        row.classList.add("border-line")
      }
    })
  }

  renderChit(count, totalPaise) {
    const hasItems = count > 0
    this.chitBarTarget.hidden = !hasItems
    this.emptyFooterTarget.hidden = hasItems
    if (!hasItems) return

    this.chitSummaryTarget.textContent = this.pluralize(count)
    const formatted = this.formatInr(totalPaise)
    this.chitTotalTarget.textContent = formatted
    this.sheetTotalTarget.textContent = formatted
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

  buildLineItem(item) {
    const li = document.createElement("li")
    li.className = "flex items-center justify-between gap-2 px-3 py-2.5 rounded-ctl bg-card border border-line"

    const label = document.createElement("span")
    label.className = "text-[17px] flex items-center gap-2 min-w-0"
    const qty = document.createElement("span")
    qty.className = "font-mono font-bold text-go shrink-0"
    qty.textContent = `${item.quantity} ×`
    const name = document.createElement("span")
    name.className = "truncate"
    name.textContent = item.name
    label.append(qty, name)

    const removeButton = document.createElement("button")
    removeButton.type = "button"
    removeButton.textContent = "हटाउनुहोस्"
    removeButton.className = "shrink-0 min-h-[40px] px-3 rounded-key text-[14px] font-bold border-[2px] border-stop text-stop active:bg-stop-50"
    removeButton.dataset.action = "order-cart#remove"
    removeButton.dataset.orderCartMenuItemIdParam = item.menuItemId

    li.append(label, removeButton)
    return li
  }

  submit() {
    const items = Array.from(this.cart.values())
    if (items.length === 0) return

    const clientToken = crypto.randomUUID()
    const payload = { clientToken, tableSessionId: this.tableSessionIdValue, items }

    this.persistPending(payload)
    this.cart.clear()
    if (this.undoTimeout) clearTimeout(this.undoTimeout)
    this.hideUndo()
    this.render()
    this.attemptSubmit(payload)
  }

  resumePendingSubmission() {
    const pending = this.readPending()
    if (pending) this.attemptSubmit(pending)
  }

  async attemptSubmit(payload) {
    this.updatePendingBanner()

    try {
      const response = await fetch(this.submitUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          client_token: payload.clientToken,
          table_session_id: payload.tableSessionId,
          items: payload.items.map((item) => ({
            menu_item_id: item.menuItemId,
            quantity: item.quantity
          }))
        })
      })

      if (!response.ok) throw new Error(`ticket submit failed: ${response.status}`)

      this.clearPending(payload.clientToken)
      window.location.reload()
    } catch {
      this.scheduleRetry(payload)
    }
  }

  scheduleRetry(payload) {
    this.retryTimeout = setTimeout(() => this.attemptSubmit(payload), 5000)
  }

  disconnect() {
    if (this.retryTimeout) clearTimeout(this.retryTimeout)
    if (this.undoTimeout) clearTimeout(this.undoTimeout)
  }

  storageKey() {
    return `pos:pending-tickets:${this.tableSessionIdValue}`
  }

  persistPending(payload) {
    const pending = this.readAllPending()
    pending.push(payload)
    localStorage.setItem(this.storageKey(), JSON.stringify(pending))
  }

  readPending() {
    return this.readAllPending()[0] ?? null
  }

  readAllPending() {
    try {
      return JSON.parse(localStorage.getItem(this.storageKey())) ?? []
    } catch {
      return []
    }
  }

  clearPending(clientToken) {
    const remaining = this.readAllPending().filter((p) => p.clientToken !== clientToken)
    localStorage.setItem(this.storageKey(), JSON.stringify(remaining))
  }

  updatePendingBanner() {
    const count = this.readAllPending().length
    this.pendingBannerTarget.hidden = count === 0
    this.pendingCountTarget.textContent = count
  }
}
