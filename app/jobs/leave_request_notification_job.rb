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
      LeaveRequestMailer.submitted(leave_request).deliver_later
      if leave_request.employee.manager.present?
        LeaveRequestMailer.pending_approval(leave_request, leave_request.employee.manager).deliver_later
      end

    when :approved
      LeaveRequestMailer.approved(leave_request).deliver_later

    when :rejected
      LeaveRequestMailer.rejected(leave_request).deliver_later

    when :cancelled
      LeaveRequestMailer.cancelled(leave_request).deliver_later

    when :pending_approval
      if recipient_id.present?
        manager = Employee.find(recipient_id)
        LeaveRequestMailer.pending_approval(leave_request, manager).deliver_later
      end

    else
      raise ArgumentError, "Action inconnue: #{action}"
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Erreur lors de l'envoi de notification: #{e.message}"
    # Ne pas relancer le job si l'enregistrement n'existe plus
  end
end
