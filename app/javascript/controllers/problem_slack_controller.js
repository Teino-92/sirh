import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["counter", "bubble"]

  connect() {
    this.element.addEventListener("mouseenter", () => this.show())
    this.element.addEventListener("mouseleave", () => this.hide())
  }

  show() {
    this.bubbleTarget.classList.remove("opacity-0", "scale-75")
    this.bubbleTarget.classList.add("opacity-100", "scale-100")
    this._count(0, 1387, 1000)
  }

  hide() {
    this.bubbleTarget.classList.add("opacity-0", "scale-75")
    this.bubbleTarget.classList.remove("opacity-100", "scale-100")
    cancelAnimationFrame(this._raf)
    this.counterTarget.textContent = "0"
  }

  _count(from, to, duration) {
    const start = performance.now()
    const tick = (now) => {
      const p = Math.min((now - start) / duration, 1)
      const eased = 1 - Math.pow(1 - p, 2)
      this.counterTarget.textContent = Math.round(from + eased * (to - from))
      if (p < 1) this._raf = requestAnimationFrame(tick)
    }
    this._raf = requestAnimationFrame(tick)
  }
}
