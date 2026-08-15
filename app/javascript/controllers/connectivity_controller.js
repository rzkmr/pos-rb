import { Controller } from "@hotwired/stimulus"
import { refresh as refreshCatalog } from "lib/catalog_cache"

// Single source of connectivity truth for the whole app — mounted once on
// <body>. Polls the existing /heartbeat endpoint (already used by the
// kitchen display) rather than trusting navigator.onLine, which reports
// "online" on a connected-but-dead WiFi — exactly this restaurant's actual
// failure mode. Hysteresis (two failures down, one success up) plus a 15s
// minimum dwell before flipping the UI keeps a flapping connection from
// making the banner flicker, which would be worse than not having one.
//
// Emits `pos:connectivity` on document with { state: "online"|"offline" }
// and mirrors it as data-connectivity on <html> so any CSS/controller can
// react without listening for the event directly.
const POLL_INTERVAL_MS = 5000
const FAILURES_TO_GO_OFFLINE = 2
const MIN_DWELL_MS = 15000

export default class extends Controller {
  connect() {
    this.consecutiveFailures = 0
    this.state = "online"
    this.lastStateChangeAt = 0
    this.poll()
    this.timer = setInterval(() => this.poll(), POLL_INTERVAL_MS)
    this.refreshCatalogQuietly()
  }

  // Best-effort — the shell only ever needs *a* cached catalog, not the
  // latest one on every page load. Failures here are not connectivity
  // signals (that's poll()'s job) and must never surface to the user.
  refreshCatalogQuietly() {
    refreshCatalog().catch(() => {})
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  async poll() {
    try {
      const response = await fetch("/heartbeat", { cache: "no-store" })
      if (response.ok) {
        this.recordSuccess()
      } else {
        this.recordFailure()
      }
    } catch {
      this.recordFailure()
    }
  }

  recordSuccess() {
    this.consecutiveFailures = 0
    this.setState("online")
  }

  recordFailure() {
    this.consecutiveFailures += 1
    if (this.consecutiveFailures >= FAILURES_TO_GO_OFFLINE) this.setState("offline")
  }

  setState(next) {
    if (next === this.state) return

    const now = Date.now()
    if (now - this.lastStateChangeAt < MIN_DWELL_MS) return

    this.state = next
    this.lastStateChangeAt = now
    document.documentElement.dataset.connectivity = next
    document.dispatchEvent(new CustomEvent("pos:connectivity", { detail: { state: next } }))
    if (next === "online") this.refreshCatalogQuietly()
  }
}
