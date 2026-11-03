import { Controller } from "@hotwired/stimulus"

// Quick-pick stake chips plus a live "what could I win?" estimate. Uses the same
// parimutuel formula as Parimutuel.projected_multiplier on the server (5% fee,
// capped at the losing side's money). It's an estimate: the pool keeps moving
// until the market locks.
export default class extends Controller {
  static targets = ["input", "estimate"]
  static values = { pools: Object, totalPool: Number, rakeRate: Number }

  pick({ params: { amount } }) {
    this.inputTarget.value = amount
    this.update()
  }

  update() {
    const selected = this.element.querySelector("input[name='outcome_id']:checked")
    const stake = parseInt(this.inputTarget.value, 10)
    this.highlightChips(stake)
    if (!selected || !stake || stake <= 0) return

    const outcomePool = (this.poolsValue[selected.value] || 0) + stake
    const total = this.totalPoolValue + stake
    const losing = total - outcomePool

    if (losing === 0) {
      this.estimateTarget.textContent = "Nobody has bet against this yet. If it stays that way, you'd get your stake back."
      return
    }

    const rake = Math.min(Math.floor(total * this.rakeRateValue), losing)
    const payout = Math.floor(((total - rake) * stake) / outcomePool)
    this.estimateTarget.textContent = `If you're right: about ${payout.toLocaleString()} credits back (×${(payout / stake).toFixed(2)}).`
  }

  highlightChips(stake) {
    this.element.querySelectorAll(".chip").forEach((chip) => {
      chip.classList.toggle("is-active", Number(chip.dataset.stakeAmountParam) === stake)
    })
  }
}
