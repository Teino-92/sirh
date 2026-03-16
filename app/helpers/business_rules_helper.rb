# frozen_string_literal: true

module BusinessRulesHelper
  TRIGGER_LABELS = {
    "leave_request.submitted"  => "Demande de congé soumise",
    "leave_request.approved"   => "Demande de congé approuvée",
    "leave_request.rejected"   => "Demande de congé refusée",
    "leave_request.cancelled"  => "Demande de congé annulée",
  }.freeze

  FIELD_LABELS = {
    "days_count"    => "Nombre de jours",
    "leave_type"    => "Type de congé",
    "employee_role" => "Rôle de l'employé",
    "department"    => "Département",
    "contract_type" => "Type de contrat",
  }.freeze

  OPERATOR_LABELS = {
    "eq"      => "est égal à",
    "neq"     => "est différent de",
    "gt"      => "est supérieur à",
    "gte"     => "est supérieur ou égal à",
    "lt"      => "est inférieur à",
    "lte"     => "est inférieur ou égal à",
    "in"      => "est dans",
    "between" => "est entre",
    "present" => "est renseigné",
    "blank"   => "est vide",
  }.freeze

  ROLE_LABELS = {
    "manager" => "Manager",
    "hr"      => "Ressources Humaines",
    "admin"   => "Administrateur",
  }.freeze

  ACTION_KEY_LABELS = {
    "role"             => "Approuvé par",
    "reason"           => "Message de blocage",
    "subject"          => "Objet de l'email",
    "message"          => "Contenu du message",
    "hours"            => "Délai (heures)",
    "escalate_to_role" => "Escalader vers",
  }.freeze

  RESULT_LABELS = {
    "executed" => ["Exécutée", "green"],
    "skipped"  => ["Ignorée",  "gray"],
    "failed"   => ["Erreur",   "red"],
  }.freeze

  ACTION_TYPE_LABELS = {
    "require_approval" => "Approbation demandée",
    "auto_approve"     => "Approbation automatique",
    "block"            => "Demande bloquée",
    "notify"           => "Notification envoyée",
    "escalate_after"   => "Escalade programmée",
  }.freeze

  def trigger_label(trigger)
    TRIGGER_LABELS[trigger] || trigger
  end

  def field_label(field)
    FIELD_LABELS[field] || field
  end

  def operator_label(op)
    OPERATOR_LABELS[op] || op
  end

  def role_label(role)
    ROLE_LABELS[role.to_s] || role
  end

  def action_key_label(key)
    ACTION_KEY_LABELS[key] || key
  end

  def result_label(result)
    RESULT_LABELS[result] || [result, "gray"]
  end

  def action_type_label(type)
    ACTION_TYPE_LABELS[type] || type
  end
end
