# frozen_string_literal: true

class LeaveRequestNotificationJob < ApplicationJob
  queue_as :default

  # Envoie des notifications par email pour les demandes de congés
  # @param action [Symbol] Type de notification (:submitted, :approved, :rejected, :cancelled, :pending_approval)
  # @param leave_request_id [Integer] ID de la demande de congé
  # @param recipient_id [Integer, nil] ID du destinataire (pour pending_approval)
  def perform(action, leave_request_id, recipient_id = nil)
    leave_request = LeaveRequest.find(leave_request_id)

    case action
    when :submitted
      # TODO: Implement LeaveRequestMailer in Sprint 2.x
      Rails.logger.info "[EMAIL] Leave request submitted: #{leave_request.id} (Employee: #{leave_request.employee.email})"
      # Notifier le manager si présent
      if leave_request.employee.manager.present?
        Rails.logger.info "[EMAIL] Pending approval notification for manager: #{leave_request.employee.manager.email}"
      end

    when :approved
      Rails.logger.info "[EMAIL] Leave request approved: #{leave_request.id} (Employee: #{leave_request.employee.email})"

    when :rejected
      Rails.logger.info "[EMAIL] Leave request rejected: #{leave_request.id} (Employee: #{leave_request.employee.email})"

    when :cancelled
      Rails.logger.info "[EMAIL] Leave request cancelled: #{leave_request.id} (Employee: #{leave_request.employee.email})"

    when :pending_approval
      if recipient_id.present?
        manager = Employee.find(recipient_id)
        Rails.logger.info "[EMAIL] Pending approval notification for manager: #{manager.email} (Leave request: #{leave_request.id})"
      end

    else
      raise ArgumentError, "Action inconnue: #{action}"
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Erreur lors de l'envoi de notification: #{e.message}"
    # Ne pas relancer le job si l'enregistrement n'existe plus
  end
end
