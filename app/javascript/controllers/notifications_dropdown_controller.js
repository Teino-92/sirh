import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="notifications-dropdown"
export default class extends Controller {
  static targets = ["dropdown"]

  toggle(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.toggle("hidden")
  }

  hide(event) {
    // Don't close if clicking inside the element
    if (!this.element.contains(event.target)) {
      this.dropdownTarget.classList.add("hidden")
    }
  }
}
