import { Controller } from "@hotwired/stimulus"

// GridStack is loaded via <script> tag in the dashboard view (UMD bundle)
// It exposes window.GridStack globally.

export default class extends Controller {
  static targets = ["grid", "card", "saveBtn", "customizeBtn", "cancelBtn", "feedback",
                    "hiddenPanel", "hiddenList", "emptyHint"]
  static values  = { saveUrl: String, mobileSaveUrl: String }

  connect() {
    this._grid = null
    this._editMode = false
    this._isMobile = window.innerWidth < 768
    this._tryInit(0)
  }

  _tryInit(attempt) {
    if (window.GridStack) {
      this._initGrid({ staticGrid: true })
      return
    }
    if (attempt >= 15) {
      console.error('[dashboard-customizer] GridStack failed to load after retries')
      return
    }
    setTimeout(() => this._tryInit(attempt + 1), 200)
  }

  disconnect() {
    if (this._grid) { this._grid.destroy(false); this._grid = null }
  }

  enterEditMode() {
    if (!this._grid) return
    this._editMode = true
    this.gridTarget.classList.add('edit-mode')
    this._grid.setStatic(false)

    this.cardTargets.forEach(card => {
      const chrome = card.querySelector('.dashboard-edit-chrome')
      if (chrome) chrome.classList.remove('hidden')
    })

    if (this.hasHiddenPanelTarget) this.hiddenPanelTarget.classList.remove('hidden')
    this._renderHiddenPills()

    this.customizeBtnTarget.style.display = 'none'
    this.saveBtnTarget.style.display      = 'inline-flex'
    if (this.hasCancelBtnTarget) this.cancelBtnTarget.style.display = 'inline-flex'
  }

  exitEditMode() {
    this._editMode = false
    this.gridTarget.classList.remove('edit-mode')
    this._grid.setStatic(true)

    this.cardTargets.forEach(card => {
      const chrome = card.querySelector('.dashboard-edit-chrome')
      if (chrome) chrome.classList.add('hidden')
    })

    if (this.hasHiddenPanelTarget) this.hiddenPanelTarget.classList.add('hidden')

    this.saveBtnTarget.style.display      = 'none'
    if (this.hasCancelBtnTarget) this.cancelBtnTarget.style.display = 'none'
    this.customizeBtnTarget.style.display = ''
  }

  save() {
    const layout  = this._collectLayout()
    const saveUrl = this._isMobile && this.hasMobileSaveUrlValue
      ? this.mobileSaveUrlValue
      : this.saveUrlValue

    this.saveBtnTarget.disabled = true
    this.saveBtnTarget.textContent = 'Sauvegarde…'

    fetch(saveUrl, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
        'Accept': 'application/json'
      },
      body: JSON.stringify({ dashboard_layout: layout })
    })
    .then(r => r.json())
    .then(data => {
      if (data.status === 'ok') {
        this._toast('Préférences sauvegardées ✓', 'green')
        this.exitEditMode()
      } else {
        this._toast('Erreur lors de la sauvegarde', 'red')
      }
    })
    .catch(() => this._toast('Erreur réseau', 'red'))
    .finally(() => {
      this.saveBtnTarget.disabled = false
      this.saveBtnTarget.innerHTML = `
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
        </svg>
        Sauvegarder`
    })
  }

  // Hide button clicked on a card in the grid
  toggleHide(event) {
    const card = event.currentTarget.closest('[data-card-id]')
    if (!card) return

    const id = card.dataset.cardId
    card.dataset.cardHidden = 'true'

    // Physically remove from GridStack (node stays in DOM, just detached from grid)
    this._grid.removeWidget(card, false)

    // Move DOM node out of grid container into a stash div
    this._getStash().appendChild(card)

    this._renderHiddenPills()
  }

  // Restore button clicked on a pill
  restoreCard(event) {
    const id = event.currentTarget.dataset.restoreId
    const card = this._getStash().querySelector(`[data-card-id="${id}"]`)
    if (!card) return

    card.dataset.cardHidden = 'false'

    // Move back into grid container, then let GridStack manage it
    this.gridTarget.appendChild(card)
    this._grid.makeWidget(card)

    // Show edit chrome since we're in edit mode
    const chrome = card.querySelector('.dashboard-edit-chrome')
    if (chrome) chrome.classList.remove('hidden')

    this._renderHiddenPills()
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  // The stash div is rendered server-side (display:none) and holds hidden card DOM nodes
  _getStash() {
    return this.element.querySelector('#dashboard-card-stash')
  }

  _initGrid(options = {}) {
    try {
      const mobileConfig = this._isMobile ? {
        column: 1,
        cellHeight: 70,
        disableResize: true,
      } : {}

      this._grid = window.GridStack.init({
        column: 12,
        cellHeight: 90,
        cellHeightUnit: 'px',
        margin: 8,
        animate: true,
        resizable: { handles: 'se' },
        draggable: { handle: '.grid-stack-item-content' },
        ...mobileConfig,
        ...options
      }, this.gridTarget)
    } catch(e) {
      console.error('[dashboard-customizer] GridStack.init threw:', e)
    }
  }

  _collectLayout() {
    const grid   = []
    const hidden = []
    const stash  = this._getStash()

    // Active cards in the grid
    this.cardTargets.forEach(card => {
      if (card.dataset.cardHidden === 'true') return
      const id   = card.dataset.cardId
      const node = card.gridstackNode
      if (!id || !node) return
      grid.push({ id, x: node.x, y: node.y, w: node.w, h: node.h })
    })

    // Hidden cards in the stash — keep their original position
    stash.querySelectorAll('[data-card-id]').forEach(card => {
      const id = card.dataset.cardId
      const x  = parseInt(card.dataset.cardX, 10) || 0
      const y  = parseInt(card.dataset.cardY, 10) || 0
      const w  = parseInt(card.dataset.cardW, 10) || 4
      const h  = parseInt(card.dataset.cardH, 10) || 3
      hidden.push(id)
      grid.push({ id, x, y, w, h })
    })

    return { grid, hidden }
  }

  _renderHiddenPills() {
    if (!this.hasHiddenListTarget) return
    const list  = this.hiddenListTarget
    const stash = this._getStash()
    const cards = Array.from(stash.querySelectorAll('[data-card-id]'))

    if (this.hasEmptyHintTarget) {
      this.emptyHintTarget.style.display = cards.length === 0 ? '' : 'none'
    }

    list.querySelectorAll('.hidden-card-pill').forEach(p => p.remove())

    cards.forEach(card => {
      const id    = card.dataset.cardId
      const label = card.dataset.cardLabel || id
      const pill  = document.createElement('button')
      pill.type      = 'button'
      pill.className = 'hidden-card-pill'
      pill.dataset.restoreId = id
      pill.dataset.action    = 'click->dashboard-customizer#restoreCard'
      pill.innerHTML = `
        <svg class="w-3 h-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4"/>
        </svg>
        <span>${label}</span>`
      list.appendChild(pill)
    })
  }

  _toast(msg, color) {
    if (!this.hasFeedbackTarget) return
    this.feedbackTarget.textContent = msg
    this.feedbackTarget.className = `fixed bottom-4 right-4 z-50 px-4 py-2 rounded-lg shadow-lg text-sm font-medium text-white bg-${color}-600`
    this.feedbackTarget.classList.remove('hidden')
    setTimeout(() => this.feedbackTarget.classList.add('hidden'), 3000)
  }
}
