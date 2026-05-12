import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthly", "yearly", "priceMonthly", "priceYearly", "form"]

  setMonthly() {
    this._setInterval("monthly")
  }

  setYearly() {
    this._setInterval("yearly")
  }

  _setInterval(interval) {
    const isYearly = interval === "yearly"

    this.monthlyTarget.classList.toggle("bg-indigo-600",  !isYearly)
    this.monthlyTarget.classList.toggle("text-white",     !isYearly)
    this.monthlyTarget.classList.toggle("text-gray-500",   isYearly)
    this.yearlyTarget.classList.toggle("bg-indigo-600",    isYearly)
    this.yearlyTarget.classList.toggle("text-white",       isYearly)
    this.yearlyTarget.classList.toggle("text-gray-500",   !isYearly)

    this.priceMonthlyTarget.classList.toggle("hidden",  isYearly)
    this.priceYearlyTarget.classList.toggle("hidden",  !isYearly)

    // Met à jour le champ hidden interval dans le form button_to
    const input = this.formTarget.querySelector("input[name='interval']")
    if (input) input.value = interval
  }
}
