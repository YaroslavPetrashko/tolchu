import { Controller } from "@hotwired/stimulus"

const ANGLES = { r: 0, ur: 45, u: 90, ul: 135, l: 180, dl: 225, d: 270, dr: 315 }
const HOLD_DELAY_MS = 250
const FAST_RAMP_AFTER_MS = 1500
const FLICK_DISTANCE_PX = 24
const FLICK_MIN_SPEED = 0.2
const HAPTICS = { raise: 8, lower: [ 5, 25, 5 ], modeRaise: 10, modeLower: [ 6, 40, 6 ], fire: 20 }

export default class extends Controller {
  static targets = [ "section", "input", "button", "submit", "stakeLabel", "modeLabel", "modeButton" ]
  static values = { pools: Object, totalPool: Number, rakeRate: Number, min: Number, max: Number, refundableStake: Number }

  connect() {
    this.mode = 1
    this.maximum = this.maxValue
    this.budgetDisabled = new Set(this.maximum < this.minValue ? this.budgetButtons : [])
    const wallet = document.getElementById("wallet-balance")
    const balance = Number(wallet?.dataset.walletBalanceAmountValue)
    if (Number.isInteger(balance) && balance >= 0) this.maximum = Math.min(100, balance + this.refundableStakeValue)
    this.normalizeStake()
    this.element.classList.add("is-enhanced")
    this.render()
  }

  disconnect() {
    this.stopRamp()
    clearTimeout(this.hintTimer)
  }

  get stake() {
    return this.inputTarget.valueAsNumber
  }

  set stake(value) {
    this.inputTarget.value = Math.min(this.maximum, Math.max(this.minValue, value))
  }

  normalizeStake() {
    this.inputTarget.max = this.maximum
    this.stake = Number.isFinite(this.stake) ? Math.trunc(this.stake) : this.minValue
  }

  updateBalance({ detail: { balance } }) {
    if (!Number.isInteger(balance) || balance < 0) return
    const maximum = Math.min(100, balance + this.refundableStakeValue)
    if (maximum === this.maximum) return
    // A wallet update must not turn an invalid entry into a different valid bet.
    const normalize = this.maximum < this.minValue || this.inputTarget.validity.valid
    this.maximum = maximum
    this.inputTarget.max = maximum
    if (normalize || maximum < this.minValue) this.normalizeStake()
    this.render()
  }

  get locked() {
    return this.element.closest(".clip-card")?.classList.contains("is-locked")
  }

  get blocked() {
    return this.waiting || this.locked || this.buttonTarget.disabled
  }

  get budgetButtons() {
    return [ this.buttonTarget, this.submitTarget, ...this.modeButtonTargets ]
  }

  setMode({ params: { mode } }) {
    if (this.blocked) return
    this.mode = mode
    buzz(mode > 0 ? HAPTICS.modeRaise : HAPTICS.modeLower)
    this.render()
  }

  startRamp() {
    if (this.blocked || !this.inputTarget.validity.valid) return
    this.ramping = true
    const startedAt = Date.now()
    this.rampTimer = setInterval(() => {
      if (this.blocked || !this.inputTarget.validity.valid) return this.cancel()
      const step = Date.now() - startedAt < FAST_RAMP_AFTER_MS ? 1 : 5
      const before = this.stake
      this.stake = before + this.mode * step
      if (this.stake !== before) buzz(this.mode > 0 ? HAPTICS.raise : HAPTICS.lower)
      this.render()
    }, this.mode > 0 ? 100 : 140)
    this.render()
  }

  stopRamp() {
    clearTimeout(this.holdTimer)
    clearInterval(this.rampTimer)
    this.ramping = false
  }

  press(event) {
    if (this.blocked || !this.inputTarget.validity.valid || event.button > 0) return
    this.buttonTarget.setPointerCapture?.(event.pointerId)
    const point = { x: event.clientX, y: event.clientY, t: event.timeStamp }
    this.gesture = { start: point, samples: [ point ], direction: null, peakSpeed: 0 }
    this.holdTimer = setTimeout(() => this.startRamp(), HOLD_DELAY_MS)
  }

  drag(event) {
    if (this.blocked) return this.cancel()
    const gesture = this.gesture
    if (!gesture) return
    const point = { x: event.clientX, y: event.clientY, t: event.timeStamp }
    this.trackSpeed(gesture, point)
    gesture.samples.push(point)
    if (gesture.samples.length > 8) gesture.samples.shift()

    const dx = point.x - gesture.start.x
    const dy = point.y - gesture.start.y
    if (Math.hypot(dx, dy) > FLICK_DISTANCE_PX) {
      this.stopRamp()
      gesture.direction = this.nearestDirection(dx, dy)
    } else {
      gesture.direction = null
    }
    this.render()
  }

  release(event) {
    if (this.blocked) return this.cancel()
    const gesture = this.gesture
    if (!gesture) return
    this.gesture = null
    const wasRamping = this.ramping
    this.stopRamp()

    if (gesture.direction) {
      this.trackSpeed(gesture, { x: event.clientX, y: event.clientY, t: event.timeStamp })
      if (gesture.peakSpeed >= FLICK_MIN_SPEED) return this.fire(gesture.direction)
      this.showHint("Flick to bet")
    } else if (!wasRamping) {
      this.step()
    }
    this.render()
  }

  cancel() {
    this.gesture = null
    this.stopRamp()
    this.render()
  }

  suppress(event) {
    event.preventDefault()
  }

  key(event) {
    if (this.blocked) {
      event.preventDefault()
      return
    }
    const steps = { ArrowUp: 1, ArrowRight: 1, ArrowDown: -1, ArrowLeft: -1 }
    if (event.key in steps) {
      event.preventDefault()
      if (this.inputTarget.validity.valid) this.stake = this.stake + steps[event.key]
      this.render()
    } else if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      const selected = this.selectedSection
      selected ? this.fire(selected.dataset.dir) : this.showHint("Pick an outcome first")
    }
  }

  nearestDirection(dx, dy) {
    let angle = (Math.atan2(-dy, dx) * 180) / Math.PI
    if (angle < 0) angle += 360
    let best = null
    let bestGap = Infinity
    for (const section of this.sectionTargets) {
      const raw = Math.abs(angle - ANGLES[section.dataset.dir])
      const gap = Math.min(raw, 360 - raw)
      if (gap < bestGap) {
        bestGap = gap
        best = section.dataset.dir
      }
    }
    return best
  }

  trackSpeed(gesture, point) {
    const from = gesture.samples.findLast((sample) => point.t - sample.t >= 30)
    if (!from) return
    const speed = Math.hypot(point.x - from.x, point.y - from.y) / (point.t - from.t)
    gesture.peakSpeed = Math.max(gesture.peakSpeed, speed)
  }

  step() {
    if (this.blocked || !this.inputTarget.validity.valid) return
    const before = this.stake
    this.stake = before + this.mode
    if (this.stake !== before) buzz(this.mode > 0 ? HAPTICS.raise : HAPTICS.lower)
  }

  fire(direction) {
    const section = this.sectionTargets.find((candidate) => candidate.dataset.dir === direction)
    if (!section || this.blocked) return
    section.querySelector("input[type=radio]").checked = true
    if (!this.element.reportValidity()) return
    buzz(HAPTICS.fire)
    this.element.requestSubmit()
  }

  submit(event) {
    if (this.blocked) event.preventDefault()
  }

  submitting() {
    this.gesture = null
    this.stopRamp()
    this.waiting = true
    this.render()
  }

  submitted() {
    this.waiting = false
    this.render()
  }

  render() {
    const stake = this.stake
    const label = Number.isFinite(stake) ? stake : "—"
    this.stakeLabelTarget.textContent = label
    this.modeLabelTarget.textContent = this.maximum < this.minValue ? "no credits" :
      `${this.mode > 0 ? "▲" : "▼"} ${this.ramping ? (this.mode > 0 ? "raising" : "lowering") : "hold"}`
    this.buttonTarget.setAttribute("aria-label",
      `Stake ${label} credits. Flick toward an outcome to bet, hold to change the stake, or use the arrow keys.`)
    this.budgetButtons.forEach((button) => {
      if (this.maximum < this.minValue && !button.disabled) {
        button.disabled = true
        this.budgetDisabled.add(button)
      } else if (this.maximum >= this.minValue && !this.locked && this.budgetDisabled.delete(button)) {
        button.disabled = false
      }
    })
    this.modeButtonTargets.forEach((button) => {
      const on = Number(button.dataset.betPadModeParam) === this.mode
      button.classList.toggle("is-on", on)
      button.setAttribute("aria-pressed", on)
    })
    this.element.classList.toggle("is-waiting", Boolean(this.waiting))
    this.element.classList.toggle("is-lowering", this.mode < 0)

    const aimed = this.gesture?.direction
    this.sectionTargets.forEach((section) => {
      const radio = section.querySelector("input[type=radio]")
      const estimate = this.inputTarget.validity.valid ? this.estimate(radio.value, stake) : null
      section.querySelector(".outcome__odds").textContent = estimate ? `×${estimate.multiple.toFixed(2)}` : "×—"
      section.querySelector(".outcome__wins").textContent = estimate ? `wins ${estimate.payout.toLocaleString()}` : "wins —"
      section.classList.toggle("is-aimed", section.dataset.dir === aimed)
      section.classList.toggle("is-selected", radio.checked)
    })
  }

  estimate(outcomeId, stake) {
    const outcomePool = (this.poolsValue[outcomeId] || 0) + stake
    const total = this.totalPoolValue + stake
    const losing = total - outcomePool
    if (losing === 0) return { multiple: 1, payout: stake }
    const rake = Math.min(Math.floor(total * this.rakeRateValue), losing)
    return { multiple: (total - rake) / outcomePool, payout: Math.floor(((total - rake) * stake) / outcomePool) }
  }

  showHint(text) {
    const hint = this.element.closest(".clip-card")?.querySelector(".bet-pad__hint")
    if (!hint) return
    clearTimeout(this.hintTimer)
    hint.textContent = text
    hint.classList.add("is-visible")
    this.hintTimer = setTimeout(() => hint.classList.remove("is-visible"), 1600)
  }

  get selectedSection() {
    return this.sectionTargets.find((section) => section.querySelector("input[type=radio]").checked)
  }

  labelOf(section) {
    return section.querySelector(".outcome__label").textContent.trim()
  }
}

function buzz(pattern) {
  navigator.vibrate?.(pattern)
}
