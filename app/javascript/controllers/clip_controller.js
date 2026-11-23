import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["video", "soundButton"]
  static values = { freezeAt: Number, revealed: Boolean }

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => entries.forEach((entry) => (entry.isIntersecting ? this.play() : this.pause())),
      { threshold: 0.6 }
    )
    this.observer.observe(this.element)
    this.watchFrames()
  }

  disconnect() {
    this.observer?.disconnect()
    if (this.frameHandle && this.videoTarget.cancelVideoFrameCallback) {
      this.videoTarget.cancelVideoFrameCallback(this.frameHandle)
    }
  }

  play() {
    if (this.isFrozen) return
    this.videoTarget.play().catch(() => {})
  }

  pause() {
    this.videoTarget.pause()
  }

  replay() {
    this.element.classList.remove("is-frozen")
    this.videoTarget.currentTime = 0
    this.videoTarget.play().catch(() => {})
  }

  toggleSound() {
    this.videoTarget.muted = !this.videoTarget.muted
    this.soundButtonTarget.textContent = this.videoTarget.muted ? "🔇" : "🔊"
    this.soundButtonTarget.setAttribute("aria-label", this.videoTarget.muted ? "Unmute clip" : "Mute clip")
  }

  enforceFreeze() {
    if (this.revealedValue) return
    const point = this.freezePoint
    if (point !== null && this.videoTarget.currentTime >= point) this.freeze()
  }

  ended() {
    if (this.revealedValue) this.element.classList.add("is-ended")
  }

  watchFrames() {
    const video = this.videoTarget
    if (!video.requestVideoFrameCallback) return

    const check = (_now, metadata) => {
      const point = this.freezePoint
      if (!this.revealedValue && point !== null && metadata.mediaTime >= point) this.freeze()
      this.frameHandle = video.requestVideoFrameCallback(check)
    }
    this.frameHandle = video.requestVideoFrameCallback(check)
  }

  freeze() {
    const video = this.videoTarget
    video.pause()
    const point = this.freezePoint
    if (point !== null && Math.abs(video.currentTime - point) > 0.05) video.currentTime = point
    this.element.classList.add("is-frozen")
  }

  // Where an unsettled clip stops, whether betting is open or closed: the creator's freeze
  // point, or the halfway mark when none was set (or it falls past the end), so the ending
  // is never shown before the result.
  get freezePoint() {
    const duration = this.videoTarget.duration
    const known = Number.isFinite(duration) && duration > 0
    if (this.freezeAtValue > 0 && !(known && this.freezeAtValue >= duration)) return this.freezeAtValue
    return known ? duration / 2 : null
  }

  get isFrozen() {
    return this.element.classList.contains("is-frozen")
  }
}
