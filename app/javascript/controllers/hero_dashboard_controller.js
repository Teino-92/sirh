import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "oneOnOneBar", "oneOnOneCount", "oneOnOneLabel",
    "okrBar", "okrPercent",
    "checkedItem", "uncheckedItem"
  ]

  connect() {
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        this._animate()
        observer.disconnect()
      }
    }, { threshold: 0.3 })
    observer.observe(this.element)
  }

  _animate() {
    // 1:1 — monte à 3/5 = 60%
    setTimeout(() => {
      this.oneOnOneBarTarget.style.width = "60%"
      this._count(this.oneOnOneCountTarget, 0, 3, 900)
      setTimeout(() => { this.oneOnOneLabelTarget.textContent = "3 faits" }, 900)
    }, 200)

    // OKR — monte à 64%
    setTimeout(() => {
      this.okrBarTarget.style.width = "64%"
      this._count(this.okrPercentTarget, 0, 64, 1200)
    }, 400)

    // Onboarding — coche les items "unchecked" avec délai
    this.uncheckedItemTargets.forEach(item => {
      const delay = parseInt(item.dataset.delay || "0") * 600 + 800
      setTimeout(() => {
        const icon = item.querySelector("span:first-child")
        const label = item.querySelector("span:last-child")
        icon.classList.remove("bg-border-soft", "text-transparent")
        icon.classList.add("bg-success/20", "text-success")
        label.classList.remove("text-muted-soft")
        label.classList.add("text-text-deep")
      }, delay)
    })
  }

  _count(el, from, to, duration) {
    const start = performance.now()
    const tick = (now) => {
      const p = Math.min((now - start) / duration, 1)
      const eased = 1 - Math.pow(1 - p, 3)
      el.textContent = Math.round(from + eased * (to - from))
      if (p < 1) requestAnimationFrame(tick)
    }
    requestAnimationFrame(tick)
  }
}
