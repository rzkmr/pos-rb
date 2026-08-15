import { Controller } from "@hotwired/stimulus"
import { read as readCatalog } from "lib/catalog_cache"

// Hydrates the chrome-only offline_shell view (see OfflineShellsController)
// from whatever's cached in IndexedDB. This page is the one thing the
// Service Worker may cache — it renders no server data itself, so there is
// nothing here that can go stale in a way that matters; staleness only
// affects how current the menu prices look, never what gets charged (the
// server always re-snapshots at order time, CLAUDE.md invariant #6).
export default class extends Controller {
  static targets = ["status", "menu"]

  async connect() {
    const catalog = await readCatalog()
    if (!catalog) {
      this.statusTarget.textContent = this.t("no_local_data")
      return
    }

    this.statusTarget.textContent = this.t("last_updated", this.formatTime(catalog.generated_at))
    this.renderMenu(catalog.menu_items || [])
  }

  renderMenu(items) {
    if (items.length === 0) {
      this.menuTarget.innerHTML = ""
      return
    }

    this.menuTarget.innerHTML = items.map((item) => `
      <div class="p-3.5 rounded-tile border border-line bg-card">
        <p class="text-[15px] font-semibold truncate">${item.name}</p>
        <p class="text-[13px] text-ink-3 font-mono mt-0.5">${this.formatInr(item.price_paise)}</p>
      </div>`).join("")
  }

  formatInr(paise) {
    const rupees = paise / 100
    return `₹${rupees.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }

  formatTime(isoString) {
    const date = new Date(isoString)
    return date.toLocaleTimeString(document.documentElement.lang === "ne" ? "ne-NP" : "en-IN", { hour: "2-digit", minute: "2-digit" })
  }

  t(key, time) {
    const locale = document.documentElement.lang
    const strings = {
      no_local_data: { en: "No local data yet — connect once, then this page works offline.", ne: "अझै स्थानीय डाटा छैन — एक पटक जडान गर्नुहोस्, त्यसपछि यो पृष्ठ अफलाइन काम गर्छ।" },
      last_updated: { en: `Menu as of ${time}`, ne: `${time} सम्मको मेनु` }
    }
    return strings[key][locale] || strings[key].en
  }
}
