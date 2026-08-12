import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["ticket"]

  connect() {
    this.knownIds = new Set(this.ticketTargets.map((el) => el.id))
    this.audioContext = null
    this.ready = true
  }

  ticketTargetConnected(element) {
    if (this.knownIds.has(element.id)) return
    this.knownIds.add(element.id)
    if (this.ready) this.beep()
  }

  beep() {
    const context = this.audioContext ||= new (window.AudioContext || window.webkitAudioContext)()
    const oscillator = context.createOscillator()
    const gain = context.createGain()
    oscillator.connect(gain)
    gain.connect(context.destination)
    oscillator.frequency.value = 880
    gain.gain.setValueAtTime(0.2, context.currentTime)
    oscillator.start()
    oscillator.stop(context.currentTime + 0.3)
  }
}
