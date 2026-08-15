import { Controller } from "@hotwired/stimulus"
import { all as allOutboxEntries } from "lib/outbox"

// Count of unsent/unconfirmed writes, visible from anywhere in the app —
// nothing offline should ever be invisible to staff. Polls rather than
// subscribing to outbox changes directly, since writes happen from several
// independent controllers (order_cart, takeaway_checkout, bill_panel, ...)
// and a shared event bus for this is more machinery than the badge needs.
const POLL_INTERVAL_MS = 3000

export default class extends Controller {
  static targets = ["count"]

  connect() {
    this.refresh()
    this.timer = setInterval(() => this.refresh(), POLL_INTERVAL_MS)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  async refresh() {
    const entries = await allOutboxEntries()
    const unsettled = entries.filter((entry) => !["applied"].includes(entry.status))
    const failed = entries.filter((entry) => ["rejected", "auth_required"].includes(entry.status))

    this.element.hidden = unsettled.length === 0
    if (this.hasCountTarget) this.countTarget.textContent = unsettled.length
    this.element.classList.toggle("bg-stop", failed.length > 0)
    this.element.classList.toggle("bg-warn", failed.length === 0)
  }
}
