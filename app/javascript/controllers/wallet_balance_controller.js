import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { amount: Number }

  connect() {
    this.dispatch("changed", { detail: { balance: this.amountValue } })
  }
}
