import { Controller } from "@hotwired/stimulus"

// Builds a cart of menu items client-side, then submits it as one ticket.
// Submission is idempotent: a client_token is generated once per ticket,
// persisted to localStorage before the request, and retried on failure —
// see CLAUDE.md invariant #2 and ARCHITECTURE.md §5. Do not remove the
// localStorage persistence; it is what survives a page refresh mid-retry.
export default class extends Controller {
  static targets = ["list", "empty", "submit", "pendingBanner", "pendingCount"]
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

    this.render()
  }

  remove(event) {
    const { menuItemId } = event.params
    this.cart.delete(menuItemId)
    this.render()
  }

  render() {
    const items = Array.from(this.cart.values())
    this.emptyTarget.hidden = items.length > 0
    this.submitTarget.disabled = items.length === 0

    this.listTarget.replaceChildren(...items.map((item) => this.buildLineItem(item)))
  }

  buildLineItem(item) {
    const li = document.createElement("li")
    li.append(`${item.quantity} × ${item.name} `)

    const removeButton = document.createElement("button")
    removeButton.type = "button"
    removeButton.textContent = "Remove"
    removeButton.dataset.action = "order-cart#remove"
    removeButton.dataset.orderCartMenuItemIdParam = item.menuItemId
    li.append(removeButton)

    return li
  }

  submit() {
    const items = Array.from(this.cart.values())
    if (items.length === 0) return

    const clientToken = crypto.randomUUID()
    const payload = { clientToken, tableSessionId: this.tableSessionIdValue, items }

    this.persistPending(payload)
    this.cart.clear()
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
