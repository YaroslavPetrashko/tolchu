import { Controller } from "@hotwired/stimulus"

// Ticks down to a market's lock time. When it hits zero the card switches to
// "Betting closed" and the bet button is disabled. The server enforces the lock
// regardless; this just keeps the UI honest.
export default class extends Controller {
  static targets = ["label", "submit"]
  static values = { locksAt: String, live: Boolean }

  connect() {
    if (!this.liveValue) return
    this.deadline = new Date(this.locksAtValue).getTime()
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  tick() {
    const remaining = this.deadline - Date.now()
    if (remaining <= 0) return this.lock()
    if (this.hasLabelTarget) this.labelTarget.textContent = `Locks in ${this.format(remaining)}`
  }

  lock() {
    clearInterval(this.timer)
    if (this.hasLabelTarget) this.labelTarget.textContent = "Betting closed"
    this.element.classList.add("is-locked")
    this.submitTargets.forEach((button) => {
      button.disabled = true
      button.value = "Betting closed"
    })
  }

  format(ms) {
    const total = Math.ceil(ms / 1000)
    const days = Math.floor(total / 86400)
    const hours = Math.floor((total % 86400) / 3600)
    const minutes = Math.floor((total % 3600) / 60)
    const seconds = total % 60
    if (days > 0) return `${days}d ${hours}h`
    if (hours > 0) return `${hours}h ${minutes}m`
    return `${minutes}:${String(seconds).padStart(2, "0")}`
  }
}
