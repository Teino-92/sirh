import { Controller } from "@hotwired/stimulus"

// Stimulus controller for the BusinessRule form builder.
// Manages dynamic condition/action rows and keeps hidden JSON fields in sync.
// Condition fields are dynamic based on the selected trigger domain.

const TRIGGER_FIELDS = {
  "leave_request.submitted":  ["days_count", "leave_type", "employee_role", "department", "contract_type"],
  "leave_request.approved":   ["days_count", "leave_type", "employee_role"],
  "leave_request.rejected":   ["days_count", "leave_type", "employee_role"],
  "leave_request.cancelled":  ["days_count", "leave_type", "employee_role"],
  "one_on_one.scheduled":     ["employee_role", "days_until", "agenda_present"],
  "one_on_one.completed":     ["employee_role"],
  "one_on_one.cancelled":     ["employee_role"],
  "objective.assigned":       ["priority", "employee_role", "deadline_days"],
  "objective.completed":      ["priority", "employee_role", "status"],
  "training_assignment.assigned":  ["training_type", "employee_role", "has_deadline", "deadline_days"],
  "training_assignment.completed": ["training_type", "employee_role"],
  "onboarding.started":       ["employee_role", "duration_days"],
  "onboarding.task_completed":["task_type", "assigned_to_role", "onboarding_day"],
  "evaluation.completed":     ["employee_role", "period_year"],
}

const ALL_FIELD_LABELS = {
  days_count:      "Nombre de jours",
  leave_type:      "Type de congé",
  employee_role:   "Rôle de l'employé",
  department:      "Département",
  contract_type:   "Type de contrat",
  priority:        "Priorité",
  status:          "Statut",
  deadline_days:   "Jours avant deadline",
  days_until:      "Jours avant le 1:1",
  agenda_present:  "Ordre du jour renseigné",
  training_type:   "Type de formation",
  has_deadline:    "A une échéance",
  task_type:       "Type de tâche",
  assigned_to_role:"Rôle assigné",
  onboarding_day:  "Jour d'onboarding",
  duration_days:   "Durée (jours)",
  period_year:     "Année de la période",
}

export default class extends Controller {
  static targets = [
    "conditionsContainer", "conditionsEmpty", "conditionsJson",
    "actionsContainer",    "actionsEmpty",    "actionsJson"
  ]

  static values = {
    conditions: Array,
    actions:    Array,
    trigger:    String,
  }

  connect() {
    this._conditions = [...(this.conditionsValue || [])]
    this._actions    = [...(this.actionsValue    || [])]
    this._trigger    = this.triggerValue || ""
    this._renderConditions()
    this._renderActions()
  }

  triggerChanged(event) {
    this._trigger = event.currentTarget.value
    this._renderConditions()
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
    // Fields available depend on the currently selected trigger
    const fieldKeys = TRIGGER_FIELDS[this._trigger] || Object.keys(ALL_FIELD_LABELS)
    const fields = fieldKeys.map(k => ({ value: k, label: ALL_FIELD_LABELS[k] || k }))

    const ops = [
      { value: "eq",      label: "est égal à" },
      { value: "neq",     label: "est différent de" },
      { value: "gt",      label: "est supérieur à" },
      { value: "gte",     label: "est supérieur ou égal à" },
      { value: "lt",      label: "est inférieur à" },
      { value: "lte",     label: "est inférieur ou égal à" },
      { value: "in",      label: "est dans la liste" },
      { value: "between", label: "est entre" },
      { value: "present", label: "est renseigné" },
      { value: "blank",   label: "est vide" },
    ]

    const fieldOpts = fields.map(f =>
      `<option value="${f.value}" ${cond.field === f.value ? "selected" : ""}>${f.label}</option>`
    ).join("")

    const opOpts = ops.map(o =>
      `<option value="${o.value}" ${cond.operator === o.value ? "selected" : ""}>${o.label}</option>`
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
               placeholder="valeur (séparer par virgule pour une liste)"
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
    const types = [
      { value: "require_approval", label: "Demander une approbation" },
      { value: "auto_approve",     label: "Approuver automatiquement" },
      { value: "block",            label: "Bloquer la demande" },
      { value: "notify",           label: "Envoyer une notification" },
      { value: "escalate_after",   label: "Escalader si pas de réponse" },
    ]
    const roles = [
      { value: "manager", label: "Manager" },
      { value: "hr",      label: "Ressources Humaines" },
      { value: "admin",   label: "Administrateur" },
    ]

    const typeOpts = types.map(t =>
      `<option value="${t.value}" ${action.type === t.value ? "selected" : ""}>${t.label}</option>`
    ).join("")

    const roleOpts = (val) => roles.map(r =>
      `<option value="${r.value}" ${val === r.value ? "selected" : ""}>${r.label}</option>`
    ).join("")

    let extraFields = ""

    switch (action.type) {
      case "require_approval":
        extraFields = `
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Approuvé par</label>
            <select data-action="change->rule-builder#updateActionField" data-idx="${idx}" data-key="role"
                    class="rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
              ${roleOpts(action.role)}
            </select>
          </div>
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Étape n°</label>
            <input type="number" min="1" value="${action.order || idx + 1}"
                   data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="order"
                   class="w-14 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
          </div>
        `
        break

      case "block":
        extraFields = `
          <input type="text" value="${this._escapeHtml(action.reason || '')}"
                 placeholder="Message affiché à l'employé…"
                 data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="reason"
                 class="flex-1 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
        `
        break

      case "notify":
        extraFields = `
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Destinataire</label>
            <select data-action="change->rule-builder#updateActionField" data-idx="${idx}" data-key="role"
                    class="rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
              ${roleOpts(action.role)}
            </select>
          </div>
          <input type="text" value="${this._escapeHtml(action.subject || '')}"
                 placeholder="Objet de l'email…"
                 data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="subject"
                 class="flex-1 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
          <input type="text" value="${this._escapeHtml(action.message || '')}"
                 placeholder="Contenu du message…"
                 data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="message"
                 class="flex-1 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
        `
        break

      case "escalate_after":
        extraFields = `
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Envoyé à</label>
            <select data-action="change->rule-builder#updateActionField" data-idx="${idx}" data-key="role"
                    class="rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
              ${roleOpts(action.role)}
            </select>
          </div>
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Délai (heures)</label>
            <input type="number" min="1" value="${action.hours || 48}"
                   data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="hours"
                   class="w-16 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
          </div>
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Escalader vers</label>
            <select data-action="change->rule-builder#updateActionField" data-idx="${idx}" data-key="escalate_to_role"
                    class="rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
              ${roleOpts(action.escalate_to_role)}
            </select>
          </div>
          <div class="flex items-center gap-1">
            <label class="text-xs text-gray-500 dark:text-gray-400">Étape n°</label>
            <input type="number" min="1" value="${action.order || idx + 1}"
                   data-action="input->rule-builder#updateActionField" data-idx="${idx}" data-key="order"
                   class="w-14 rounded border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 text-xs py-1 focus:ring-indigo-500">
          </div>
        `
        break

      case "auto_approve":
      default:
        extraFields = `<span class="text-xs text-gray-400 dark:text-gray-500 italic">Aucun paramètre nécessaire</span>`
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
