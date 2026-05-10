import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { threshold: { type: Number, default: 0.15 } }

  connect() {
    this.element.classList.add("reveal-init")

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.element.classList.add("reveal-shown")
      return
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("reveal-shown")
          this.observer.unobserve(entry.target)
        }
      })
    }, { threshold: this.thresholdValue })

    this.observer.observe(this.element)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }
}
