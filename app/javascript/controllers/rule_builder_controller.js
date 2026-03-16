import { Controller } from "@hotwired/stimulus"

// Stimulus controller for the BusinessRule form builder.
// Manages dynamic condition/action rows and keeps hidden JSON fields in sync.
export default class extends Controller {
  static targets = [
    "conditionsContainer", "conditionsEmpty", "conditionsJson",
    "actionsContainer",    "actionsEmpty",    "actionsJson"
  ]

  static values = {
    conditions: Array,
    actions:    Array
  }

  connect() {
    this._conditions = [...(this.conditionsValue || [])]
    this._actions    = [...(this.actionsValue    || [])]
    this._renderConditions()
    this._renderActions()
  }

  // ── Conditions ──────────────────────────────────────────────────────────────

  addCondition() {
    this._conditions.push({ field: "", operator: "eq", value: "" })
    this._renderConditions()
  }

  removeCondition(event) {
    const idx = parseInt(event.currentTarget.dataset.idx)
    this._conditions.splice(idx, 1)
    this._renderConditions()
  }

  updateCondition(event) {
    const el  = event.currentTarget
    const idx = parseInt(el.dataset.idx)
    const key = el.dataset.key
    this._conditions[idx] = { ...this._conditions[idx], [key]: el.value }
    this._syncConditionsJson()
  }

  _renderConditions() {
    this.conditionsContainerTarget.innerHTML = this._conditions.map((c, i) =>
      this._conditionRowHtml(c, i)
    ).join("")
    this._toggleEmpty(this.conditionsEmptyTarget, this._conditions.length === 0)
    this._syncConditionsJson()
  }

  _conditionRowHtml(cond, idx) {
    const fields = ["days_count", "leave_type", "employee_role", "department", "contract_type"]
    const ops    = ["eq", "neq", "gt", "gte", "lt", "lte", "in", "between", "present", "blank"]

    const fieldOpts = fields.map(f =>
      `<option value="${f}" ${cond.field === f ? "selected" : ""}>${f}</option>`
    ).join("")

    const opOpts = ops.map(o =>
      `<option value="${o}" ${cond.operator === o ? "selected" : ""}>${o}</option>`
    ).join("")

    const valueIsArray = Array.isArray(cond.value)
    const valueStr = valueIsArray ? cond.value.join(", ") : (cond.value ?? "")

    return `
      <div class="flex items-center gap-2 flex-wrap bg-gray-50 dark:bg-gray-700/50 rounded p-2">
        <select data-action="change->rule-builder#updateCondition"
                data-idx="${idx}" data-key="field"
                class="rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
          <option value="">— champ —</option>
          ${fieldOpts}
          <option value="${cond.field}" ${fields.includes(cond.field) ? "hidden" : ""}>${cond.field}</option>
        </select>

        <select data-action="change->rule-builder#updateCondition"
                data-idx="${idx}" data-key="operator"
                class="rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
          ${opOpts}
        </select>

        <input type="text"
               value="${this._escapeHtml(String(valueStr))}"
               placeholder="valeur (virgule pour liste)"
               data-action="input->rule-builder#updateConditionValue"
               data-idx="${idx}"
               class="flex-1 min-w-24 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">

        <button type="button"
                data-action="click->rule-builder#removeCondition"
                data-idx="${idx}"
                class="text-red-400 hover:text-red-600 dark:hover:text-red-400 flex-shrink-0">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    `
  }

  updateConditionValue(event) {
    const el  = event.currentTarget
    const idx = parseInt(el.dataset.idx)
    const raw = el.value.trim()

    // Auto-detect comma-separated list → array
    const value = raw.includes(",")
      ? raw.split(",").map(s => s.trim()).filter(Boolean)
      : (isNaN(raw) || raw === "" ? raw : parseFloat(raw))

    this._conditions[idx] = { ...this._conditions[idx], value }
    this._syncConditionsJson()
  }

  _syncConditionsJson() {
    this.conditionsJsonTarget.value = JSON.stringify(this._conditions)
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  addAction() {
    const order = this._actions.length + 1
    this._actions.push({ type: "require_approval", role: "manager", order })
    this._renderActions()
  }

  removeAction(event) {
    const idx = parseInt(event.currentTarget.dataset.idx)
    this._actions.splice(idx, 1)
    // Renuméroter les order
    this._actions.forEach((a, i) => { if (a.order !== undefined) a.order = i + 1 })
    this._renderActions()
  }

  updateActionType(event) {
    const el   = event.currentTarget
    const idx  = parseInt(el.dataset.idx)
    const type = el.value
    const prev = this._actions[idx]

    // Réinitialise l'action selon le type
    const templates = {
      require_approval: { type, role: prev.role || "manager", order: prev.order || idx + 1 },
      auto_approve:     { type, order: prev.order || idx + 1 },
      block:            { type, reason: prev.reason || "", order: prev.order || idx + 1 },
      notify:           { type, role: "hr", subject: "", message: "", order: prev.order || idx + 1 },
      escalate_after:   { type, role: "manager", hours: 48, escalate_to_role: "hr", order: prev.order || idx + 1 },
    }
    this._actions[idx] = templates[type] || { type, order: idx + 1 }
    this._renderActions()
  }

  updateActionField(event) {
    const el  = event.currentTarget
    const idx = parseInt(el.dataset.idx)
    const key = el.dataset.key
    let val   = el.value

    if (key === "order" || key === "hours") val = parseInt(val) || 0

    this._actions[idx] = { ...this._actions[idx], [key]: val }
    this._syncActionsJson()
  }

  _renderActions() {
    this.actionsContainerTarget.innerHTML = this._actions.map((a, i) =>
      this._actionRowHtml(a, i)
    ).join("")
    this._toggleEmpty(this.actionsEmptyTarget, this._actions.length === 0)
    this._syncActionsJson()
  }

  _actionRowHtml(action, idx) {
    const types = ["require_approval", "auto_approve", "block", "notify", "escalate_after"]
    const roles  = ["manager", "hr", "admin"]

    const typeOpts = types.map(t =>
      `<option value="${t}" ${action.type === t ? "selected" : ""}>${t}</option>`
    ).join("")

    const roleOpts = (val) => roles.map(r =>
      `<option value="${r}" ${val === r ? "selected" : ""}>${r}</option>`
    ).join("")

    let extraFields = ""

    switch (action.type) {
      case "require_approval":
        extraFields = `
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Rôle</label>
            <select data-action="change->rule-builder#updateActionField" data-idx="${idx}" data-key="role"
                    class="rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
              ${roleOpts(action.role)}
            </select>
          </div>
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Ordre</label>
            <input type="number" min="1" value="${action.order || idx + 1}"
                   data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="order"
                   class="w-14 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
          </div>
        `
        break

      case "block":
        extraFields = `
          <input type="text" value="${this._escapeHtml(action.reason || '')}"
                 placeholder="Raison du blocage…"
                 data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="reason"
                 class="flex-1 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
        `
        break

      case "notify":
        extraFields = `
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Dest.</label>
            <select data-action="change->rule-builder#updateActionField" data-idx="${idx}" data-key="role"
                    class="rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
              ${roleOpts(action.role)}
            </select>
          </div>
          <input type="text" value="${this._escapeHtml(action.subject || '')}"
                 placeholder="Objet…"
                 data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="subject"
                 class="flex-1 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
          <input type="text" value="${this._escapeHtml(action.message || '')}"
                 placeholder="Message…"
                 data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="message"
                 class="flex-1 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
        `
        break

      case "escalate_after":
        extraFields = `
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Rôle init.</label>
            <select data-action="change->rule-builder#updateActionField" data-idx="${idx}" data-key="role"
                    class="rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
              ${roleOpts(action.role)}
            </select>
          </div>
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Heures</label>
            <input type="number" min="1" value="${action.hours || 48}"
                   data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="hours"
                   class="w-16 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
          </div>
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">→ escalade vers</label>
            <select data-action="change->rule-builder#updateActionField" data-idx="${idx}" data-key="escalate_to_role"
                    class="rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
              ${roleOpts(action.escalate_to_role)}
            </select>
          </div>
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Ordre</label>
            <input type="number" min="1" value="${action.order || idx + 1}"
                   data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="order"
                   class="w-14 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
          </div>
        `
        break

      case "auto_approve":
      default:
        extraFields = `<span class="text-xs text-gray-400 dark:text-gray-500 italic">Aucun paramètre</span>`
        break
    }

    return `
      <div class="flex items-center gap-2 flex-wrap bg-gray-50 dark:bg-gray-700/50 rounded p-2">
        <select data-action="change->rule-builder#updateActionType"
                data-idx="${idx}"
                class="rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500 font-medium">
          ${typeOpts}
        </select>

        ${extraFields}

        <button type="button"
                data-action="click->rule-builder#removeAction"
                data-idx="${idx}"
                class="ml-auto text-red-400 hover:text-red-600 dark:hover:text-red-400 flex-shrink-0">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    `
  }

  _syncActionsJson() {
    this.actionsJsonTarget.value = JSON.stringify(this._actions)
  }

  // ── Utils ────────────────────────────────────────────────────────────────────

  _toggleEmpty(el, show) {
    el.classList.toggle("hidden", !show)
  }

  _escapeHtml(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }
}
