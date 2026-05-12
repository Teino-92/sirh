import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["word"]
  static values  = { words: Array }

  connect() {
    this._index = 0
    this._el = this.wordTarget
    this._colors = [
      "var(--color-primary)",
      "var(--color-success)",
      "var(--color-warning)",
      "#E07AA0",
    ]
    this._el.style.color = this._colors[0]
    setTimeout(() => this._next(), 2000)
  }

  _next() {
    this._index = (this._index + 1) % this.wordsValue.length
    const next  = this.wordsValue[this._index]
    const color = this._colors[this._index % this._colors.length]

    // sortie vers le haut
    this._el.style.transform  = "translateY(-110%)"
    this._el.style.opacity    = "0"

    setTimeout(() => {
      this._el.textContent      = next
      this._el.style.color      = color
      this._el.style.transition = "none"
      this._el.style.transform  = "translateY(110%)"
      this._el.style.opacity    = "0"

      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          this._el.style.transition = "transform 0.4s cubic-bezier(0.22,1,0.36,1), opacity 0.3s ease"
          this._el.style.transform  = "translateY(0)"
          this._el.style.opacity    = "1"
        })
      })
    }, 400)

    setTimeout(() => this._next(), 2600)
  }
}
