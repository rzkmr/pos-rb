import { Controller } from "@hotwired/stimulus"
import { all as allOutboxEntries } from "lib/outbox"

// Count of unsent/unconfirmed writes, visible from anywhere in the app —
// nothing offline should ever be invisible to staff. Polls rather than
// subscribing to outbox changes directly, since writes happen from several
// independent controllers (order_cart, takeaway_checkout, bill_panel,
// offline_shell, ...) and a shared event bus for this is more machinery
// than the badge needs.
//
// auth_required specifically means: this device recorded and printed real
// money, but the Rails session that would let it reach the server has
// expired or never existed (e.g. a cold-started offline shell that never
// signed in). That money is safe locally — it just can't move until a
// human signs in — so this state gets its own color and a tap-to-sign-in,
// not just a bigger number.
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
    const authRequired = entries.filter((entry) => entry.status === "auth_required")
    const failed = entries.filter((entry) => entry.status === "rejected")

    this.element.hidden = unsettled.length === 0
    if (this.hasCountTarget) this.countTarget.textContent = unsettled.length
    this.element.classList.toggle("bg-stop", failed.length > 0 && authRequired.length === 0)
    this.element.classList.toggle("bg-ink", authRequired.length > 0)
    this.element.classList.toggle("bg-warn", failed.length === 0 && authRequired.length === 0)
    this.element.classList.toggle("text-surface", authRequired.length > 0)
    this.element.classList.toggle("text-warn-900", authRequired.length === 0)

    if (authRequired.length > 0) {
      this.element.dataset.action = "click->pending-badge#goToSignIn"
      this.element.style.cursor = "pointer"
    } else {
      delete this.element.dataset.action
      this.element.style.cursor = ""
    }
  }

  goToSignIn() {
    window.location.href = "/session/new"
  }
}
