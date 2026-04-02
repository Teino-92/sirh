import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]

  toggle() {
    const isOpen = !this.contentTarget.classList.contains("hidden")
    this.contentTarget.classList.toggle("hidden", isOpen)
    this.iconTarget.style.transform = isOpen ? "" : "rotate(180deg)"
  }
}
