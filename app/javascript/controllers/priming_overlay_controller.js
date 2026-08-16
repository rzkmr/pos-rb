import { Controller } from "@hotwired/stimulus"
import { ensurePrimed } from "lib/priming"

// Shown only on a genuinely unprimed browser (fresh install, first sign-in
// ever, or IndexedDB was cleared) — blocks nothing for the normal case,
// which resolves instantly since the catalog is already cached. This
// exists because a fire-and-forget catalog fetch that never gets to finish
// (tab closed moments after sign-in) is exactly how "installed the PWA,
// went offline, nothing works" happens on the very first shift.
export default class extends Controller {
  static targets = ["status", "spinner", "retryButton"]

  async connect() {
    const result = await ensurePrimed({ onStatusChange: (status) => this.render(status) })

    if (result) {
      this.element.hidden = true
    } else {
      this.render("failed")
    }
  }

  render(status) {
    if (status === "ready") {
      this.element.hidden = true
      return
    }

    this.element.hidden = false
    this.statusTarget.textContent = this.t(status)
    this.spinnerTarget.hidden = status === "failed"
    this.retryButtonTarget.hidden = status !== "failed"
  }

  retry() {
    this.connect()
  }

  t(key) {
    const locale = document.documentElement.lang
    const strings = {
      priming: { en: "Getting ready for offline use...", ne: "अफलाइनको लागि तयार हुँदैछ..." },
      failed: { en: "Couldn't finish setting up offline mode. You're still online — try again, or just continue.", ne: "अफलाइन मोड मिलाउन सकिएन। तपाईं अझै अनलाइन हुनुहुन्छ — फेरि प्रयास गर्नुहोस्, वा जारी राख्नुहोस्।" }
    }
    return strings[key][locale] || strings[key].en
  }
}
