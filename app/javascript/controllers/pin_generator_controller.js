import { Controller } from "@hotwired/stimulus"

// Fills the target field with a random 4-digit PIN so admin doesn't have
// to invent one by hand. Purely client-side — the field still submits
// through the normal form, so the server validates and stores it as usual.
export default class extends Controller {
  static targets = ["field"]

  generate() {
    const pin = Math.floor(1000 + Math.random() * 9000).toString()
    this.fieldTarget.value = pin
    this.fieldTarget.type = "text"
  }
}
