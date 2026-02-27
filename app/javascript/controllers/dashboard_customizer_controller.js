import { Controller } from "@hotwired/stimulus"
import Sortable       from "sortablejs"

export default class extends Controller {
  static targets = ["grid", "card", "saveBtn", "customizeBtn", "feedback"]
  static values  = { saveUrl: String }

  connect() {
    this._sortable = null
    this.cardTargets.forEach(c => {
      if (c.dataset.cardHidden === 'true') c.classList.add('dashboard-card--hidden')
    })
  }

  disconnect() { this._destroySortable() }

  enterEditMode() {
    this.cardTargets.forEach(c => {
      c.classList.remove('dashboard-card--hidden')
      const content = c.querySelector('.card-content')
      if (content) content.style.opacity = c.dataset.cardHidden === 'true' ? '0.3' : ''
      const chrome = c.querySelector('.dashboard-edit-chrome')
      if (chrome) chrome.style.display = 'flex'
    })
    this._initSortable()
    this.customizeBtnTarget.style.display = 'none'
    this.saveBtnTarget.style.display      = 'inline-flex'
  }

  exitEditMode() {
    this._destroySortable()
    this.cardTargets.forEach(c => {
      const chrome = c.querySelector('.dashboard-edit-chrome')
      if (chrome) chrome.style.display = 'none'
      const content = c.querySelector('.card-content')
      if (content) content.style.opacity = ''
      if (c.dataset.cardHidden === 'true') c.classList.add('dashboard-card--hidden')
    })
    this.saveBtnTarget.style.display      = 'none'
    this.customizeBtnTarget.style.display = ''
  }

  save() {
    const layout = this._collectLayout()
    fetch(this.saveUrlValue, {
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
  }

  toggleHide(event) {
    const card      = event.currentTarget.closest('[data-card-id]')
    const hidden    = card.dataset.cardHidden === 'true'
    const nowHidden = !hidden
    card.dataset.cardHidden = nowHidden ? 'true' : 'false'
    const content = card.querySelector('.card-content')
    if (content) content.style.opacity = nowHidden ? '0.3' : ''
    card.querySelector('[data-eye-open]')?.classList.toggle('hidden', nowHidden)
    card.querySelector('[data-eye-closed]')?.classList.toggle('hidden', !nowHidden)
  }

  setSize(event) {
    const size = event.params.size
    const card = event.currentTarget.closest('[data-card-id]')
    card.dataset.cardSize = size
    card.style.width = size === 'wide' ? '66.666%' : '33.333%'
    card.querySelectorAll('[data-size-btn]').forEach(btn => {
      const active = btn.dataset.sizeBtn === size
      btn.classList.toggle('bg-indigo-600', active)
      btn.classList.toggle('text-white',    active)
      btn.classList.toggle('bg-gray-100',   !active)
      btn.classList.toggle('dark:bg-gray-700', !active)
    })
  }

  _initSortable() {
    this._sortable = new Sortable(this.gridTarget, {
      animation:      200,
      handle:         '[data-drag-handle]',
      ghostClass:     'sortable-ghost',
      dragClass:      'sortable-drag',
      forceFallback:  false,
      fallbackOnBody: true,
      scroll:         true,
      bubbleScroll:   true
    })
  }

  _destroySortable() {
    if (this._sortable) { this._sortable.destroy(); this._sortable = null }
  }

  _collectLayout() {
    const order = [], hidden = [], sizes = {}
    this.cardTargets.forEach(card => {
      const id = card.dataset.cardId
      order.push(id)
      sizes[id] = card.dataset.cardSize || 'normal'
      if (card.dataset.cardHidden === 'true') hidden.push(id)
    })
    return { order, hidden, sizes }
  }

  _toast(msg, color) {
    if (!this.hasFeedbackTarget) return
    this.feedbackTarget.textContent = msg
    this.feedbackTarget.className = `fixed bottom-4 right-4 z-50 px-4 py-2 rounded-lg shadow-lg text-sm font-medium text-white bg-${color}-600`
    this.feedbackTarget.classList.remove('hidden')
    setTimeout(() => this.feedbackTarget.classList.add('hidden'), 3000)
  }
}
