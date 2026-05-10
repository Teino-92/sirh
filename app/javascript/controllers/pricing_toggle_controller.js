import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthly", "yearly", "toggle"]
  static classes = ["active"]

  connect() {
    this.showMonthly()
  }

  showMonthly() {
    this.monthlyTargets.forEach(el => el.classList.remove("hidden"))
    this.yearlyTargets.forEach(el => el.classList.add("hidden"))
    this.toggleTarget.dataset.mode = "monthly"
  }

  showYearly() {
    this.yearlyTargets.forEach(el => el.classList.remove("hidden"))
    this.monthlyTargets.forEach(el => el.classList.add("hidden"))
    this.toggleTarget.dataset.mode = "yearly"
  }

  toggle() {
    if (this.toggleTarget.dataset.mode === "monthly") {
      this.showYearly()
    } else {
      this.showMonthly()
    }
  }
}
