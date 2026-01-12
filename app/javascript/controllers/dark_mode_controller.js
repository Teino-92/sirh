import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dark-mode"
export default class extends Controller {
  static targets = ["icon"]

  connect() {
    // Check for saved theme preference or default to light mode
    const savedTheme = localStorage.getItem('theme')

    if (savedTheme === 'dark' || (!savedTheme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
      this.enableDarkMode()
    } else {
      this.enableLightMode()
    }
  }

  toggle() {
    if (document.documentElement.classList.contains('dark')) {
      this.enableLightMode()
    } else {
      this.enableDarkMode()
    }
  }

  enableDarkMode() {
    document.documentElement.classList.add('dark')
    localStorage.setItem('theme', 'dark')
    this.updateIcon()
  }

  enableLightMode() {
    document.documentElement.classList.remove('dark')
    localStorage.setItem('theme', 'light')
    this.updateIcon()
  }

  updateIcon() {
    // Icon will be updated via CSS classes
  }
}
