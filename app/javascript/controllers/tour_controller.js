import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    name: String,
    autostart: { type: Boolean, default: true }
  }

  #steps = []
  #currentStep = 0
  #overlay = null
  #tooltip = null
  #highlightedEl = null
  #boundNext = null
  #boundPrev = null
  #boundSkip = null
  #boundFinish = null

  connect() {
    if (this.autostartValue && !this.#isDone()) {
      // Small delay to let the page fully render
      setTimeout(() => this.start(), 400)
    }
  }

  disconnect() {
    this.#cleanup()
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  start() {
    this.#steps = this.#collectSteps()
    if (this.#steps.length === 0) return
    this.#currentStep = 0
    this.#buildOverlay()
    this.#showStep(0)
  }

  next() {
    const nextIndex = this.#currentStep + 1
    if (nextIndex >= this.#steps.length) {
      this.finish()
    } else {
      this.#showStep(nextIndex)
    }
  }

  prev() {
    const prevIndex = this.#currentStep - 1
    if (prevIndex >= 0) {
      this.#showStep(prevIndex)
    }
  }

  skip() {
    this.#markDone()
    this.#cleanup()
  }

  finish() {
    this.#markDone()
    this.#cleanup()
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  #collectSteps() {
    const els = Array.from(
      document.querySelectorAll("[data-tour-step]")
    )
    // Sort by the numeric step value
    return els
      .map(el => ({
        el,
        index: parseInt(el.dataset.tourStep, 10),
        title: el.dataset.tourTitle || "",
        description: el.dataset.tourDescription || ""
      }))
      .filter(s => !isNaN(s.index))
      .sort((a, b) => a.index - b.index)
  }

  #buildOverlay() {
    if (this.#overlay) return
    const el = document.createElement("div")
    el.id = "tour-overlay"
    el.className = "fixed inset-0 bg-black/40 z-[900]"
    document.body.appendChild(el)
    this.#overlay = el
  }

  #buildTooltip(step, index, total) {
    const isFirst = index === 0
    const isLast = index === total - 1

    const el = document.createElement("div")
    el.id = "tour-tooltip"
    el.className =
      "fixed z-[910] max-w-xs w-full bg-white dark:bg-gray-800 rounded-xl shadow-2xl border border-gray-200 dark:border-gray-700 p-4"

    // Progress dots HTML
    const dots = Array.from({ length: total }, (_, i) => {
      const active = i === index
        ? "bg-indigo-600"
        : "bg-gray-300 dark:bg-gray-600"
      return `<span class="inline-block w-2 h-2 rounded-full ${active}"></span>`
    }).join("")

    el.innerHTML = `
      <div class="flex items-center justify-between mb-2">
        <span class="text-xs font-medium text-indigo-600 dark:text-indigo-400">Étape ${index + 1} / ${total}</span>
        <button id="tour-skip-btn" class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 text-xs transition-colors">Passer</button>
      </div>
      <h3 class="text-sm font-semibold text-gray-900 dark:text-gray-100 mb-1">${this.#escapeHtml(step.title)}</h3>
      <p class="text-xs text-gray-600 dark:text-gray-400 mb-4">${this.#escapeHtml(step.description)}</p>
      <div class="flex gap-1 justify-center mb-3">${dots}</div>
      <div class="flex justify-between items-center">
        <button id="tour-prev-btn"
          class="text-xs text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 disabled:opacity-30 transition-colors"
          ${isFirst ? "disabled" : ""}>
          ← Précédent
        </button>
        <button id="tour-next-btn"
          class="text-xs font-medium text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg px-3 py-1.5 transition-colors">
          ${isLast ? "Terminer ✓" : "Suivant →"}
        </button>
      </div>
    `

    document.body.appendChild(el)
    this.#tooltip = el

    // Wire up buttons with addEventListener (tooltip is outside controller DOM)
    this.#boundSkip = () => this.skip()
    this.#boundPrev = () => this.prev()
    this.#boundNext = isLast ? () => this.finish() : () => this.next()

    el.querySelector("#tour-skip-btn").addEventListener("click", this.#boundSkip)
    el.querySelector("#tour-prev-btn").addEventListener("click", this.#boundPrev)
    el.querySelector("#tour-next-btn").addEventListener("click", this.#boundNext)
  }

  #positionTooltip(targetEl, tooltipEl) {
    const rect = targetEl.getBoundingClientRect()
    const vh = window.innerHeight
    const vw = window.innerWidth

    // Mobile: center fixed at bottom
    if (vw < 640) {
      tooltipEl.style.left = "50%"
      tooltipEl.style.transform = "translateX(-50%)"
      tooltipEl.style.bottom = "16px"
      tooltipEl.style.top = "auto"
      return
    }

    // Desktop: above or below
    const tooltipH = tooltipEl.offsetHeight || 200
    const tooltipW = tooltipEl.offsetWidth || 320
    const gap = 12

    // Determine vertical position
    const belowSpace = vh - rect.bottom
    const placeAbove = rect.top > vh * 0.6 || belowSpace < tooltipH + gap

    // Horizontal: align with target center, clamped to viewport (fixed coords)
    const fixedLeft = rect.left + rect.width / 2 - tooltipW / 2
    const clampedLeft = Math.max(12, Math.min(fixedLeft, vw - tooltipW - 12))

    tooltipEl.style.position = "fixed"
    tooltipEl.style.transform = "none"
    tooltipEl.style.left = `${clampedLeft}px`

    if (placeAbove) {
      tooltipEl.style.top = `${rect.top - tooltipH - gap}px`
      tooltipEl.style.bottom = "auto"
    } else {
      tooltipEl.style.top = `${rect.bottom + gap}px`
      tooltipEl.style.bottom = "auto"
    }
  }

  #highlightElement(el) {
    this.#removeHighlight()
    el.classList.add("ring-2", "ring-indigo-500", "ring-offset-2", "relative", "z-[905]")
    this.#highlightedEl = el
  }

  #removeHighlight() {
    if (this.#highlightedEl) {
      this.#highlightedEl.classList.remove(
        "ring-2", "ring-indigo-500", "ring-offset-2", "relative", "z-[905]"
      )
      this.#highlightedEl = null
    }
  }

  #showStep(index) {
    // Remove previous tooltip
    this.#removeTooltip()

    // Find a visible step starting from index
    let actualIndex = index
    while (actualIndex < this.#steps.length) {
      const step = this.#steps[actualIndex]
      if (step.el && step.el.offsetParent !== null) break
      actualIndex++
    }

    if (actualIndex >= this.#steps.length) {
      this.finish()
      return
    }

    this.#currentStep = actualIndex
    const step = this.#steps[actualIndex]

    // Highlight target
    this.#highlightElement(step.el)

    // Scroll to target
    step.el.scrollIntoView({ behavior: "smooth", block: "center" })

    // Wait for scroll, then build + position tooltip
    setTimeout(() => {
      this.#buildTooltip(step, actualIndex, this.#steps.length)
      this.#positionTooltip(step.el, this.#tooltip)
    }, 300)
  }

  #removeTooltip() {
    if (this.#tooltip) {
      // Clean up listeners before removing
      const skipBtn = this.#tooltip.querySelector("#tour-skip-btn")
      const prevBtn = this.#tooltip.querySelector("#tour-prev-btn")
      const nextBtn = this.#tooltip.querySelector("#tour-next-btn")
      if (skipBtn && this.#boundSkip) skipBtn.removeEventListener("click", this.#boundSkip)
      if (prevBtn && this.#boundPrev) prevBtn.removeEventListener("click", this.#boundPrev)
      if (nextBtn && this.#boundNext) nextBtn.removeEventListener("click", this.#boundNext)
      this.#tooltip.remove()
      this.#tooltip = null
    }
  }

  #cleanup() {
    this.#removeTooltip()
    this.#removeHighlight()
    if (this.#overlay) {
      this.#overlay.remove()
      this.#overlay = null
    }
  }

  #isDone() {
    return localStorage.getItem(`izi-tour-${this.nameValue}-done`) === "1"
  }

  #markDone() {
    localStorage.setItem(`izi-tour-${this.nameValue}-done`, "1")
  }

  #escapeHtml(str) {
    const div = document.createElement("div")
    div.appendChild(document.createTextNode(str))
    return div.innerHTML
  }
}
