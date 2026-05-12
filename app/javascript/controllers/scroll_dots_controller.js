import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dot"]
  static values  = { count: Number }

  connect() {
    this._scroller = this.element.previousElementSibling
    if (!this._scroller) return
    this._scroller.addEventListener("scroll", this._onScroll.bind(this), { passive: true })
    this._update(0)
  }

  disconnect() {
    this._scroller?.removeEventListener("scroll", this._onScroll.bind(this))
  }

  _onScroll() {
    const el    = this._scroller
    const width = el.scrollWidth - el.clientWidth
    if (width <= 0) return
    const ratio = el.scrollLeft / width
    const index = Math.round(ratio * (this.countValue - 1))
    this._update(index)
  }

  _update(active) {
    this.dotTargets.forEach((dot, i) => {
      dot.classList.toggle("bg-primary", i === active)
      dot.classList.toggle("w-4",        i === active)
      dot.classList.toggle("bg-border-soft", i !== active)
      dot.classList.toggle("w-2",        i !== active)
    })
  }
}
