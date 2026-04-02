import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "overlay", "hamburger"]

  connect() {
    this._onKeydown = this._handleKeydown.bind(this)
    document.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
  }

  open() {
    this.drawerTarget.classList.remove("-translate-x-full")
    this.overlayTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    const firstLink = this.drawerTarget.querySelector("a, button")
    if (firstLink) firstLink.focus()
  }

  close() {
    this.drawerTarget.classList.add("-translate-x-full")
    this.overlayTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    if (this.hasHamburgerTarget) this.hamburgerTarget.focus()
  }

  toggle() {
    const isOpen = !this.drawerTarget.classList.contains("-translate-x-full")
    isOpen ? this.close() : this.open()
  }

  closeOnOverlay(event) {
    if (event.target === this.overlayTarget) this.close()
  }

  _handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }
}
