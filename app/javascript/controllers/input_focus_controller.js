import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  activate(event) {
    event.currentTarget.classList.add("ring-2", "ring-primary")
    event.currentTarget.classList.remove("ring-success", "ring-red-500")
  }

  validate(event) {
    const input = event.currentTarget
    input.classList.remove("ring-2", "ring-primary")
    if (!input.value) return

    if (input.checkValidity()) {
      input.classList.add("ring-2", "ring-success")
    } else {
      input.classList.add("ring-2", "ring-red-500")
    }
  }
}
