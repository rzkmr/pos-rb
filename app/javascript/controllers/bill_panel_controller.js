import { Controller } from "@hotwired/stimulus"

// Turns the bill's plain forms (payment, void, discount) into tap-first
// controls: method/reason chips fill a hidden field instead of free text,
// and cash entry shows quick amount buttons plus a live change display.
// Submission is still a normal Rails form POST — no client-side state,
// no risk of drifting from the server's paise math.
export default class extends Controller {
  static targets = [
    "methodChip", "methodField", "payAmount", "payMoreFields", "paySubmit",
    "cashChip", "changeDisplay",
    "voidReasonChip", "voidReasonField", "voidReasonOther", "voidSubmit",
    "discountChip", "discountAmountField", "discountReasonField", "discountCustom"
  ]
  static values = { remainingPaise: Number }

  connect() {
    if (this.hasMethodChipTarget) this.selectMethod(this.methodChipTargets[0])
  }

  // --- payment method chips ---
  chooseMethod(event) {
    this.selectMethod(event.currentTarget)
  }

  selectMethod(chip) {
    const method = chip.dataset.billPanelMethodParam
    this.methodChipTargets.forEach((c) => {
      const active = c === chip
      c.classList.toggle("border-go", active)
      c.classList.toggle("bg-go-50", active)
      c.classList.toggle("text-go", active)
      c.classList.toggle("border-line-2", !active)
    })
    this.methodFieldTarget.value = method

    const isCash = method === "cash"
    this.payMoreFieldsTargets.forEach((el) => { el.hidden = !isCash })
    if (!isCash) {
      this.payAmountTarget.value = this.remainingPaiseValue
      this.changeDisplayTarget.innerHTML = ""
      this.paySubmitTarget.disabled = false
    } else {
      this.updateChange()
    }
  }

  // --- cash quick amounts ---
  setCashAmount(event) {
    this.payAmountTarget.value = event.currentTarget.dataset.billPanelAmountParam
    this.updateChange()
  }

  typeCashAmount(event) {
    this.payAmountTarget.value = event.currentTarget.value
    this.updateChange()
  }

  updateChange() {
    if (!this.hasChangeDisplayTarget) return
    const received = parseInt(this.payAmountTarget.value, 10) || 0
    const change = received - this.remainingPaiseValue

    this.cashChipTargets.forEach((chip) => {
      chip.classList.toggle("border-go", parseInt(chip.dataset.billPanelAmountParam, 10) === received)
    })

    if (received <= 0) {
      this.changeDisplayTarget.innerHTML = ""
      this.paySubmitTarget.disabled = true
      return
    }

    if (change < 0) {
      this.changeDisplayTarget.innerHTML = `<div class="text-center text-[16px] font-semibold text-stop">${this.t("insufficient")}</div>`
      this.paySubmitTarget.disabled = true
    } else {
      this.changeDisplayTarget.innerHTML = `
        <div class="flex items-center justify-between px-4 py-3 rounded-ctl bg-go text-surface">
          <span class="text-[17px] font-semibold">${this.t("change_due")}</span>
          <span class="text-[24px] font-mono font-bold">${this.formatInr(change)}</span>
        </div>`
      this.paySubmitTarget.disabled = false
    }
  }

  // --- void reason chips ---
  chooseVoidReason(event) {
    const chip = event.currentTarget
    const reason = chip.dataset.billPanelReasonParam
    this.voidReasonChipTargets.forEach((c) => {
      const active = c === chip
      c.classList.toggle("border-stop", active)
      c.classList.toggle("bg-stop-50", active)
      c.classList.toggle("border-line-2", !active)
    })
    this.voidReasonFieldTarget.value = reason
    if (this.hasVoidReasonOtherTarget) this.voidReasonOtherTarget.value = ""
    this.voidSubmitTarget.disabled = false
  }

  typeVoidReason(event) {
    const value = event.currentTarget.value.trim()
    this.voidReasonFieldTarget.value = value
    this.voidReasonChipTargets.forEach((c) => c.classList.remove("border-stop", "bg-stop-50"))
    this.voidSubmitTarget.disabled = value.length === 0
  }

  // --- discount chips ---
  chooseDiscount(event) {
    const chip = event.currentTarget
    this.discountChipTargets.forEach((c) => c.classList.remove("border-go", "bg-go-50"))
    chip.classList.add("border-go", "bg-go-50")
    this.discountAmountFieldTarget.value = chip.dataset.billPanelAmountParam
    this.discountReasonFieldTarget.value = chip.dataset.billPanelReasonParam
    if (this.hasDiscountCustomTarget) this.discountCustomTarget.value = ""
  }

  typeCustomDiscount(event) {
    this.discountAmountFieldTarget.value = event.currentTarget.value
    this.discountChipTargets.forEach((c) => c.classList.remove("border-go", "bg-go-50"))
  }

  // --- helpers ---
  formatInr(paise) {
    const rupees = paise / 100
    return `₹${rupees.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  }

  t(key) {
    const locale = document.documentElement.lang
    const strings = {
      change_due: { en: "Change due", ne: "फिर्ता रकम" },
      insufficient: { en: "Insufficient amount", ne: "रकम अपुग छ" }
    }
    return strings[key][locale] || strings[key].en
  }
}
