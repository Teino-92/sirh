import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "searchIcon", "clearBtn", "count"]

  perform() {
    const query = this.inputTarget.value.trim().toLowerCase()

    // Toggle icons
    this.searchIconTarget.classList.toggle("hidden", query.length > 0)
    this.clearBtnTarget.classList.toggle("hidden", query.length === 0)

    // Filter rows
    const rows = document.querySelectorAll("#employees tr[data-search]")
    let visible = 0
    rows.forEach(row => {
      const match = query === "" || row.dataset.search.includes(query)
      row.classList.toggle("hidden", !match)
      if (match) visible++
    })

    // Update counter
    if (this.hasCountTarget) {
      this.countTarget.textContent = visible
    }

    // Empty state
    const empty = document.getElementById("search-empty")
    if (empty) empty.classList.toggle("hidden", visible > 0)
  }

  clear(event) {
    event.preventDefault()
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.perform()
  }
}
