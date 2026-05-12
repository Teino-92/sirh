import { Controller } from "@hotwired/stimulus"

const DATA = [
  ["Dupont M.", "2 834 €", "Q3-24", "=B2*1.1", "validé"],
  ["Martin L.", "=SUM(A:A)", "???", "3 102 €", "#REF!"],
  ["Bernard K.", "1 980 €", "Q2-24", "=C3/0",  "en cours"],
  ["Petit S.",  "#N/A",    "Q1-24", "2 450 €", "=VLOOKUP"],
]

const LOOP_INTERVAL = 9000

export default class extends Controller {
  connect() {
    this._cells  = this.element.querySelectorAll(".problem-spreadsheet-cell .cell-value")
    this._timers = []

    if (window.matchMedia("(pointer: coarse)").matches) {
      this._startLoop()
    } else {
      this.element.addEventListener("mouseenter", () => this.flood())
      this.element.addEventListener("mouseleave", () => this.clear())
    }
  }

  disconnect() {
    clearInterval(this._loop)
    this._timers.forEach(t => clearTimeout(t))
  }

  flood() {
    this._cells.forEach((cell, i) => {
      const row   = Math.floor(i / 5)
      const col   = i % 5
      const delay = (row * 5 + col) * 60
      const t = setTimeout(() => {
        cell.textContent = DATA[row]?.[col] ?? ""
        cell.classList.add("text-gray-800")
        if (DATA[row]?.[col]?.startsWith("#") || DATA[row]?.[col]?.startsWith("=")) {
          cell.classList.add("text-red-500")
        }
      }, delay)
      this._timers.push(t)
    })
  }

  clear() {
    this._timers.forEach(t => clearTimeout(t))
    this._timers = []
    this._cells.forEach(cell => {
      cell.textContent = ""
      cell.classList.remove("text-gray-800", "text-red-500")
    })
  }

  _startLoop() {
    const cycle = () => {
      this.flood()
      setTimeout(() => this.clear(), 3500)
    }
    cycle()
    this._loop = setInterval(cycle, LOOP_INTERVAL)
  }
}
