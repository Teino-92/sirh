# frozen_string_literal: true
  # Authorization handled by authorize_manager! before_action

module Manager
  class TimeEntriesController < ApplicationController
    before_action :authenticate_employee!
    before_action :authorize_manager!
    before_action :set_team_member, only: [:index, :validate_week]
    skip_before_action :verify_authenticity_token, only: [:reject_entry]

    def index
      @time_entries = policy_scope(TimeEntry)
                        .where(employee: @team_member)
                        .order(clock_in: :desc)
                        .limit(100)

      @pending_entries = @time_entries.pending_validation
      @validated_entries = @time_entries.validated
    end

    def validate_week
      week_start = params[:week_start]&.to_date || Date.current.beginning_of_week
      week_end = week_start + 6.days

      entries = @team_member.time_entries
                            .completed
                            .pending_validation
                            .for_date_range(week_start, week_end)

      validated_count = 0
      entries.each do |entry|
        authorize entry, :validate?
        if entry.validate!(validator: current_employee)
          validated_count += 1
        end
      end

      # Create notification for the employee
      if validated_count > 0
        @team_member.notifications.create!(
          title: 'Heures validées',
          message: "Vos heures de travail pour la semaine du #{I18n.l(week_start, format: :short)} ont été validées par votre manager (#{validated_count} pointage#{'s' if validated_count > 1}).",
          notification_type: 'hours_validated'
        )
      end

      redirect_to manager_team_member_time_entries_path(@team_member),
                  notice: "#{validated_count} pointage#{'s' if validated_count > 1} validé#{'s' if validated_count > 1}"
    end

    def validate_entry
      @time_entry = TimeEntry.find(params[:id])
      authorize @time_entry, :validate?

      if @time_entry.validate!(validator: current_employee)
        @time_entry.employee.notifications.create!(
          title: 'Pointage validé',
          message: "Votre pointage du #{I18n.l(@time_entry.worked_date, format: :long)} a été validé.",
          notification_type: 'hours_validated'
        )

        redirect_to manager_team_member_time_entries_path(@time_entry.employee),
                    notice: 'Pointage validé avec succès'
      else
        redirect_to manager_team_member_time_entries_path(@time_entry.employee),
                    alert: 'Impossible de valider ce pointage'
      end
    end

    def reject_entry
      @time_entry = TimeEntry.find(params[:id])
      authorize @time_entry, :validate?

      if @time_entry.reject!(rejector: current_employee, reason: params[:rejection_reason])
        @time_entry.employee.notifications.create!(
          title: 'Pointage refusé',
          message: "Votre pointage du #{I18n.l(@time_entry.worked_date, format: :long)} a été refusé par votre manager. Raison: #{params[:rejection_reason]}",
          notification_type: 'hours_rejected'
        )

        redirect_to manager_team_member_time_entries_path(@time_entry.employee),
                    notice: 'Pointage refusé'
      else
        redirect_to manager_team_member_time_entries_path(@time_entry.employee),
                    alert: 'Impossible de refuser ce pointage'
      end
    end

    private

    def set_team_member
      @team_member = current_employee.team_members.find(params[:team_member_id])
    end

    def authorize_manager!
      unless current_employee.manager?
        redirect_to dashboard_path, alert: 'Accès réservé aux managers'
      end
    end
  end
end
