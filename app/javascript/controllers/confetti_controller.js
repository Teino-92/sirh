import { Controller } from "@hotwired/stimulus"
import confetti from "canvas-confetti"

export default class extends Controller {
  fire() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    confetti({
      particleCount: 80,
      spread: 70,
      origin: { y: 0.7 },
      colors: ["#7C6FF7", "#7BAE8A", "#F4A96A"]
    })
  }
}
