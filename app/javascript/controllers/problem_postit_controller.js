import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("mouseenter", () => this.scatter())
    this.element.addEventListener("mouseleave", () => this.stack())
    this._notes = this.element.querySelectorAll(".problem-postit")
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
}
