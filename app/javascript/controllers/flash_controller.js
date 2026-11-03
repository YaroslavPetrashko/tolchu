import { Controller } from "@hotwired/stimulus"

// Dismissible flash message that also fades out on its own after a few seconds.
export default class extends Controller {
  connect() {
    this.timeout = setTimeout(() => this.dismiss(), 6000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.add("is-leaving")
    setTimeout(() => this.element.remove(), 250)
  }
}
