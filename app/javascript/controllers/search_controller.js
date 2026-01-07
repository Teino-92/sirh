import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  static targets = ["searchIcon", "clearBtn", "input", "form"]

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  perform(event) {
    // Toggle icons
    const hasValue = this.inputTarget.value.length > 0
    if (hasValue) {
      this.searchIconTarget.classList.add('hidden')
      this.clearBtnTarget.classList.remove('hidden')
    } else {
      this.searchIconTarget.classList.remove('hidden')
      this.clearBtnTarget.classList.add('hidden')
    }

    // Debounced search - 1 seconde pour laisser le temps de taper
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 1000)
  }

  clear(event) {
    event.preventDefault()
    this.inputTarget.value = ''
    this.searchIconTarget.classList.remove('hidden')
    this.clearBtnTarget.classList.add('hidden')
    this.formTarget.requestSubmit()
  }
}
