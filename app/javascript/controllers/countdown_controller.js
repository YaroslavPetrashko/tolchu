import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["label", "submit", "clock", "ring", "retry"]
  static values = { locksAt: String, opensAt: String, serverNow: String, live: Boolean, refreshUrl: String }

  connect() {
    if (!this.liveValue) return
    this.connected = true
    this.locked = false
    this.refreshAttempts = 0
    this.deadline = new Date(this.locksAtValue).getTime()
    this.window = this.deadline - new Date(this.opensAtValue).getTime()
    this.serverTime = new Date(this.serverNowValue).getTime()
    this.startedAt = performance.now()
    this.wasHidden = document.hidden
    this.visibilityChanged = () => {
      if (document.hidden) this.wasHidden = true
      else if (this.wasHidden) {
        this.wasHidden = false
        this.resume()
      }
    }
    this.pageShown = (event) => { if (event.persisted) this.resume() }
    this.beforeCache = () => { this.element.dataset.countdownCached = "true" }
    document.addEventListener("visibilitychange", this.visibilityChanged)
    document.addEventListener("turbo:before-cache", this.beforeCache)
    window.addEventListener("pageshow", this.pageShown)
    this.tick()
    if (!this.locked) this.timer = setInterval(() => this.tick(), 1000)
    if (this.element.dataset.countdownCached) this.scheduleRefresh(0)
  }

  disconnect() {
    this.connected = false
    clearInterval(this.timer)
    clearTimeout(this.refreshTimer)
    clearTimeout(this.requestTimer)
    this.refreshTimer = null
    this.refreshAbort?.abort()
    this.refreshAbort = null
    document.removeEventListener("visibilitychange", this.visibilityChanged)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    window.removeEventListener("pageshow", this.pageShown)
  }

  tick() {
    const remaining = this.deadline - (this.serverTime + performance.now() - this.startedAt)
    if (remaining <= 0) return this.lock()
    if (this.hasLabelTarget) this.labelTarget.textContent = `Locks in ${this.format(remaining)}`
    if (this.hasClockTarget) this.clockTarget.textContent = this.clock(remaining)
    this.drainRings(remaining)
  }

  lock() {
    if (this.locked) return
    this.locked = true
    clearInterval(this.timer)
    if (this.hasLabelTarget) this.labelTarget.textContent = "Betting closed"
    if (this.hasClockTarget) this.clockTarget.textContent = "0:00"
    this.drainRings(0)
    this.element.classList.add("is-locked")
    this.element.querySelectorAll(".bet-pad--live button, .bet-pad--live input, .bet-pad--live select, .bet-pad--live textarea").forEach((control) => {
      control.disabled = true
    })
    this.submitTargets.forEach((button) => {
      button.disabled = true
      button.value = "Betting closed"
    })
    this.scheduleRefresh(800)
  }

  resume() {
    // A fresh render also recalibrates clocks that pause while the device sleeps.
    this.tick()
    this.scheduleRefresh(0)
  }

  scheduleRefresh(delay) {
    if (!this.connected || !this.hasRefreshUrlValue || this.refreshTimer || this.refreshAbort || this.refreshAttempts >= 3) return
    this.refreshTimer = setTimeout(() => {
      this.refreshTimer = null
      this.refresh()
    }, delay)
  }

  drainRings(remaining) {
    const left = this.window > 0 ? Math.min(Math.max(remaining / this.window, 0), 1) : 0
    this.ringTargets.forEach((ring) => {
      ring.querySelector(".bet-pad__ring-fill").style.strokeDashoffset = 100 * (1 - left)
      ring.classList.toggle("is-ending", remaining <= 10_000)
    })
  }

  async refresh() {
    if (!this.connected || this.refreshAbort) return
    this.refreshAttempts += 1
    const abort = new AbortController()
    this.refreshAbort = abort
    const requestTimer = this.requestTimer = setTimeout(() => abort.abort(), 10_000)
    let failed = false
    try {
      const response = await fetch(this.refreshUrlValue, {
        headers: { Accept: "text/vnd.turbo-stream.html" }, cache: "no-store", signal: abort.signal
      })
      if (!response.ok) throw new Error("Card refresh failed")
      const stream = await response.text()
      if (this.connected && this.refreshAbort === abort && !abort.signal.aborted) Turbo.renderStreamMessage(stream)
    } catch {
      if (this.refreshAbort !== abort) return
      failed = true
    } finally {
      clearTimeout(requestTimer)
      if (this.refreshAbort === abort) this.refreshAbort = null
    }
    if (failed && this.connected) {
      if (this.refreshAttempts < 3) this.scheduleRefresh(this.refreshAttempts * 1000)
      else this.showRetry()
    }
  }

  showRetry() {
    const hint = this.element.querySelector(".bet-pad__hint")
    if (hint) {
      hint.textContent = "Couldn't update this market."
      hint.classList.remove("bet-pad__hint--error")
      hint.classList.add("is-visible")
    }
    if (this.hasRetryTarget) {
      this.retryTarget.hidden = false
      this.retryTarget.querySelector("button").disabled = false
    }
  }

  retry(event) {
    event.currentTarget.disabled = true
    this.refreshAttempts = 0
    this.scheduleRefresh(0)
  }

  clock(ms) {
    const total = Math.ceil(ms / 1000)
    const hours = Math.floor(total / 3600)
    const minutes = Math.floor((total % 3600) / 60)
    const seconds = String(total % 60).padStart(2, "0")
    return hours > 0 ? `${hours}:${String(minutes).padStart(2, "0")}:${seconds}` : `${minutes}:${seconds}`
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
