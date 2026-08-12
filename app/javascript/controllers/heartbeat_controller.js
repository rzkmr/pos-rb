import { Controller } from "@hotwired/stimulus"

const PING_INTERVAL_MS = 5000
const STALE_AFTER_MS = 15000

export default class extends Controller {
  static targets = ["staleSeconds"]
  static values = { url: String }

  connect() {
    this.lastSuccessAt = Date.now()
    this.pingTimer = setInterval(() => this.ping(), PING_INTERVAL_MS)
    this.staleTimer = setInterval(() => this.checkStale(), 1000)
  }

  disconnect() {
    clearInterval(this.pingTimer)
    clearInterval(this.staleTimer)
  }

  async ping() {
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "text/plain" } })
      if (response.ok) {
        this.lastSuccessAt = Date.now()
        this.wasStale = false
        this.hideOverlay()
      }
    } catch (error) {
      // handled by checkStale via lastSuccessAt
    }
  }

  checkStale() {
    const elapsedMs = Date.now() - this.lastSuccessAt
    if (elapsedMs > STALE_AFTER_MS) {
      if (!this.wasStale) this.dispatch("stale")
      this.wasStale = true
      this.showOverlay(Math.floor(elapsedMs / 1000))
    }
  }

  showOverlay(seconds) {
    this.element.hidden = false
    if (this.hasStaleSecondsTarget) {
      this.staleSecondsTarget.textContent = seconds
    }
  }

  hideOverlay() {
    this.element.hidden = true
  }
}
