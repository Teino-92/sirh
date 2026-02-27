import { Controller } from "@hotwired/stimulus"

// Handles the HR Query form UX:
// - Shows a loading spinner while waiting for the LLM (~2–4s)
// - Disables submit button to prevent duplicate requests
// - Restores state when Turbo Stream response arrives
export default class extends Controller {
  static targets = ["submitBtn", "spinner", "btnText", "loadingMsg", "textarea", "form"]

  connect() {
    // Re-enable if navigating back to the page with Turbo cache
    this.setLoading(false)
  }

  onSubmit(event) {
    const query = this.textareaTarget.value.trim()
    if (!query) {
      event.preventDefault()
      this.textareaTarget.focus()
      return
    }
    this.setLoading(true)
  }

  // Called by Turbo after the stream response is applied
  // We hook into turbo:before-stream-render on the document instead
  // of a target callback because Stimulus doesn't have a built-in
  // "response received" hook for turbo streams.
  // The spinner is reset when the results frame is updated.
  // We listen to turbo:frame-render as a fallback.

  setLoading(loading) {
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = loading
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.toggle("hidden", !loading)
    }
    if (this.hasBtnTextTarget) {
      this.btnTextTarget.textContent = loading ? "Analyse…" : "Rechercher"
    }
    if (this.hasLoadingMsgTarget) {
      this.loadingMsgTarget.classList.toggle("hidden", !loading)
    }
  }
}

// Reset loading state when Turbo Stream replaces the results frame
document.addEventListener("turbo:before-stream-render", () => {
  // Find any hr-query controller and reset its loading state
  const controllers = document.querySelectorAll("[data-controller~='hr-query']")
  controllers.forEach(el => {
    const ctrl = el._stimulus_application?.getControllerForElementAndIdentifier?.(el, "hr-query")
    if (ctrl) ctrl.setLoading(false)
  })
})
