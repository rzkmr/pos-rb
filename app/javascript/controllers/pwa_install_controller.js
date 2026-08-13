import { Controller } from "@hotwired/stimulus"

// Registers the assets-only service worker (see app/views/pwa/service-worker.js
// — never caches HTML, per CLAUDE.md invariant #4) and shows a one-time
// "Add to Home Screen" banner so staff open a real app icon instead of
// typing a URL every shift. Chrome/Android fires beforeinstallprompt;
// iOS Safari has no such event, so there we show a manual instruction
// instead of a button. Dismissed state is remembered per-browser.
export default class extends Controller {
  static STORAGE_KEY = "pos:install-prompt-dismissed"

  connect() {
    this.registerServiceWorker()

    if (this.isStandalone() || this.wasDismissed()) return

    window.addEventListener("beforeinstallprompt", this.handleInstallPrompt)

    if (this.isIos() && !this.isStandalone()) {
      this.showBanner({ ios: true })
    }
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.handleInstallPrompt)
  }

  registerServiceWorker() {
    if (!("serviceWorker" in navigator)) return
    navigator.serviceWorker.register("/service-worker.js", { scope: "/" }).catch(() => {})
  }

  handleInstallPrompt = (event) => {
    event.preventDefault()
    this.deferredPrompt = event
    this.showBanner({ ios: false })
  }

  showBanner({ ios }) {
    if (this.bannerElement) return

    const banner = document.createElement("div")
    banner.className =
      "fixed left-3 right-3 bottom-3 z-[60] flex items-center gap-3 px-4 py-3.5 rounded-tile bg-ink text-surface shadow-2xl"

    const text = document.createElement("span")
    text.className = "flex-1 text-[15px] font-semibold"
    text.textContent = ios
      ? this.iosInstructionText()
      : this.installPromptText()
    banner.append(text)

    if (!ios) {
      const installButton = document.createElement("button")
      installButton.type = "button"
      installButton.className = "shrink-0 min-h-[40px] px-4 rounded-key bg-go text-surface text-[15px] font-bold"
      installButton.textContent = this.installButtonText()
      installButton.addEventListener("click", () => this.promptInstall())
      banner.append(installButton)
    }

    const dismissButton = document.createElement("button")
    dismissButton.type = "button"
    dismissButton.className = "shrink-0 min-h-[40px] px-3 text-[15px] font-bold text-surface/70"
    dismissButton.textContent = "✕"
    dismissButton.addEventListener("click", () => this.dismiss())
    banner.append(dismissButton)

    document.body.append(banner)
    this.bannerElement = banner
  }

  async promptInstall() {
    if (!this.deferredPrompt) return
    this.deferredPrompt.prompt()
    await this.deferredPrompt.userChoice
    this.deferredPrompt = null
    this.dismiss()
  }

  dismiss() {
    localStorage.setItem(this.constructor.STORAGE_KEY, "1")
    this.bannerElement?.remove()
    this.bannerElement = null
  }

  wasDismissed() {
    return localStorage.getItem(this.constructor.STORAGE_KEY) === "1"
  }

  isStandalone() {
    return window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true
  }

  isIos() {
    return /iphone|ipad|ipod/i.test(window.navigator.userAgent)
  }

  installButtonText() {
    return document.documentElement.lang === "ne" ? "इन्स्टल गर्नुहोस्" : "Install"
  }

  installPromptText() {
    return document.documentElement.lang === "ne"
      ? "यो डिभाइसमा एप जस्तै राख्नुहोस्"
      : "Add this to the home screen"
  }

  iosInstructionText() {
    return document.documentElement.lang === "ne"
      ? "Share बटन थिच्नुहोस् → 'Add to Home Screen'"
      : "Tap Share → \"Add to Home Screen\""
  }
}
