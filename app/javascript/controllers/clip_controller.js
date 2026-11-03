import { Controller } from "@hotwired/stimulus"

// Plays a market's clip. While the market is undecided, playback stops on the
// freeze frame (the instant before the action) so viewers predict with full
// context but never see the result early. Once settled, the whole clip plays.
//
// Clips autoplay muted when at least 60% of the card is on screen and pause
// when scrolled away, like a short-video feed.
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
    this.videoTarget.play().catch(() => {}) // Autoplay can be refused; the replay button still works.
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

  // Fallback check on timeupdate/seeking for browsers without requestVideoFrameCallback.
  enforceFreeze() {
    if (this.revealedValue || this.freezeAtValue <= 0) return
    if (this.videoTarget.currentTime >= this.freezeAtValue) this.freeze()
  }

  ended() {
    if (this.revealedValue) this.element.classList.add("is-ended")
  }

  // Frame-accurate freeze where supported, so the action never leaks past the freeze point.
  watchFrames() {
    const video = this.videoTarget
    if (!video.requestVideoFrameCallback) return

    const check = (_now, metadata) => {
      if (!this.revealedValue && this.freezeAtValue > 0 && metadata.mediaTime >= this.freezeAtValue) this.freeze()
      this.frameHandle = video.requestVideoFrameCallback(check)
    }
    this.frameHandle = video.requestVideoFrameCallback(check)
  }

  freeze() {
    const video = this.videoTarget
    video.pause()
    if (Math.abs(video.currentTime - this.freezeAtValue) > 0.05) video.currentTime = this.freezeAtValue
    this.element.classList.add("is-frozen")
  }

  get isFrozen() {
    return this.element.classList.contains("is-frozen")
  }
}
