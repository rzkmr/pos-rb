import { Controller } from "@hotwired/stimulus"

// Slim, non-blocking bar reacting to connectivity_controller's
// `pos:connectivity` event. Reserves its own height (via the `hidden`
// attribute rather than display toggling on a zero-height wrapper) so it
// never shifts a payment screen under a cashier's finger when it appears.
export default class extends Controller {
  connect() {
    this.listener = (event) => this.render(event.detail.state)
    document.addEventListener("pos:connectivity", this.listener)
    this.render(document.documentElement.dataset.connectivity || "online")
  }

  disconnect() {
    document.removeEventListener("pos:connectivity", this.listener)
  }

  render(state) {
    this.element.hidden = state !== "offline"
  }
}
