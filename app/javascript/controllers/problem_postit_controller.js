import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._notes = this.element.querySelectorAll(".problem-postit")

    if (window.matchMedia("(pointer: coarse)").matches) {
      this.element.addEventListener("touchstart", () => this._onTouch(), { passive: true })
    } else {
      this.element.addEventListener("mouseenter", () => this.scatter())
      this.element.addEventListener("mouseleave", () => this.stack())
    }
  }

  disconnect() {
    clearTimeout(this._resetTimer)
  }

  scatter() {
    this._notes.forEach(note => {
      note.style.left      = note.dataset.fl
      note.style.top       = note.dataset.ft
      note.style.transform = `rotate(${note.dataset.frot})`
    })
  }

  stack() {
    this._notes.forEach(note => {
      note.style.left      = note.dataset.il
      note.style.top       = note.dataset.it
      note.style.transform = `rotate(${note.dataset.irot})`
    })
  }

  _onTouch() {
    this.scatter()
    clearTimeout(this._resetTimer)
    this._resetTimer = setTimeout(() => this.stack(), 3000)
  }
}
