# frozen_string_literal: true

class LeaveRequestMailer < ApplicationMailer
  default from: 'noreply@easy-rh.com'

  # Notification envoyée à l'employé après soumission de sa demande
  def submitted(leave_request)
    @leave_request = leave_request
    @employee = leave_request.employee
    @manager = leave_request.employee.manager

    mail(
      to: @employee.email,
      subject: "Demande de congé soumise - #{@leave_request.leave_type_label}"
    )
  end

  # Notification envoyée à l'employé lorsque sa demande est approuvée
  def approved(leave_request)
    @leave_request = leave_request
    @employee = leave_request.employee
    @approver = leave_request.approver

    mail(
      to: @employee.email,
      subject: "Demande de congé approuvée - #{@leave_request.leave_type_label}"
    )
  end

  # Notification envoyée à l'employé lorsque sa demande est rejetée
  def rejected(leave_request)
    @leave_request = leave_request
    @employee = leave_request.employee
    @approver = leave_request.approver
    @rejection_reason = leave_request.rejection_reason

    mail(
      to: @employee.email,
      subject: "Demande de congé refusée - #{@leave_request.leave_type_label}"
    )
  end

  # Notification envoyée à l'employé et au manager lorsqu'une demande est annulée
  def cancelled(leave_request)
    @leave_request = leave_request
    @employee = leave_request.employee
    @manager = leave_request.employee.manager

    recipients = [@employee.email]
    recipients << @manager.email if @manager.present?

    mail(
      to: recipients.uniq,
      subject: "Demande de congé annulée - #{@leave_request.leave_type_label}"
    )
  end

  # Notification envoyée au manager lorsqu'une nouvelle demande nécessite son approbation
  def pending_approval(leave_request, manager)
    @leave_request = leave_request
    @employee = leave_request.employee
    @manager = manager

    mail(
      to: @manager.email,
      subject: "Nouvelle demande de congé à approuver - #{@employee.full_name}"
    )
  end
end
