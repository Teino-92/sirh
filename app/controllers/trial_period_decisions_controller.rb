# frozen_string_literal: true

class TrialPeriodDecisionsController < ApplicationController
  before_action :authenticate_employee!
  before_action :set_employee

  def confirm
    authorize @employee, :confirm?, policy_class: TrialPeriodDecisionPolicy
    notify_hr('confirm')
    redirect_to dashboard_path, notice: "Période d'essai de #{@employee.full_name} validée. Les RH ont été informés."
  end

  def renew
    authorize @employee, :renew?, policy_class: TrialPeriodDecisionPolicy
    new_end = @employee.trial_period_end + 1.month
    @employee.update!(trial_period_end: new_end)
    notify_hr('renew')
    redirect_to dashboard_path, notice: "Période d'essai de #{@employee.full_name} renouvelée jusqu'au #{I18n.l(new_end, format: :long)}. Les RH ont été informés."
  end

  def terminate
    authorize @employee, :terminate?, policy_class: TrialPeriodDecisionPolicy
    notify_hr('terminate')
    redirect_to dashboard_path, notice: "Fin de période d'essai de #{@employee.full_name} signalée aux RH."
  end

  private

  def set_employee
    @employee = current_employee.organization.employees.find(params[:id])
  end

  def notify_hr(decision)
    ActiveRecord::Base.transaction do
      Notification.where(
        organization:      current_employee.organization,
        notification_type: 'trial_period_decision',
        related_type:      'Employee',
        related_id:        @employee.id
      ).destroy_all

      current_employee.organization.employees.where(role: %w[hr admin]).find_each do |hr|
        Notification.create!(
          organization:      current_employee.organization,
          employee:          hr,
          title:             "Décision période d'essai — #{@employee.full_name}",
          message:           decision_body(decision),
          notification_type: 'trial_period_decision',
          related_type:      'Employee',
          related_id:        @employee.id
        )
      end
    end

    TrialPeriodMailer.decision_to_hr(@employee, current_employee, decision).deliver_later
  end

  DECISION_LABELS = {
    'confirm'   => 'Validée',
    'renew'     => 'Renouvelée',
    'terminate' => 'Fin de collaboration'
  }.freeze

  def decision_body(decision)
    label = DECISION_LABELS.fetch(decision, decision)
    "#{current_employee.full_name} a décidé : #{label} pour #{@employee.full_name}."
  end
end
