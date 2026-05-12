import { Controller } from "@hotwired/stimulus"

const LOOP_INTERVAL = 11000

export default class extends Controller {
  connect() {
    this._notes = this.element.querySelectorAll(".problem-postit")

    if (window.matchMedia("(pointer: coarse)").matches) {
      this._startLoop()
    } else {
      this.element.addEventListener("mouseenter", () => this.scatter())
      this.element.addEventListener("mouseleave", () => this.stack())
    }
  }

  disconnect() {
    clearInterval(this._loop)
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

  _startLoop() {
    const cycle = () => {
      this.scatter()
      setTimeout(() => this.stack(), 3000)
    }
    cycle()
    this._loop = setInterval(cycle, LOOP_INTERVAL)
  }
}
