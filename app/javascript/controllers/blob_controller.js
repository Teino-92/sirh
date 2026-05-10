import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 8000 } }

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    this.element.style.setProperty("--blob-duration", `${this.durationValue}ms`)
    this.element.classList.add("blob-active")
  }
}
