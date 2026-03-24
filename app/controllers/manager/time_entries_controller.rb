# frozen_string_literal: true
  # Authorization handled by authorize_manager! before_action

module Manager
  class TimeEntriesController < BaseController
    before_action :set_team_member, only: [:index, :validate_week]
    skip_before_action :verify_authenticity_token, only: [:reject_entry]

    def index
      @time_entries = policy_scope(TimeEntry)
                        .where(employee: @team_member)
                        .order(clock_in: :desc)
                        .limit(100)
                        .includes(:employee, :validated_by)

      @pending_entries = @time_entries.pending_validation
      @validated_entries = @time_entries.validated

      # Complementary hours summary per week for part-time employees
      if @team_member.work_schedule&.part_time?
        @complementary_hours_by_week = @time_entries
          .group_by { |te| te.worked_date.beginning_of_week }
          .transform_values do |entries|
            ComplementaryHoursCalculatorService.new(
              @team_member,
              week_start: entries.first.worked_date.beginning_of_week
            ).call
          end
      end
    end

    def validate_week
      week_start = params[:week_start]&.to_date || Date.current.beginning_of_week
      week_end = week_start + 6.days

      entries = @team_member.time_entries
                            .completed
                            .pending_validation
                            .for_date_range(week_start, week_end)

      validated_count = 0
      locked_count    = 0
      entries.each do |entry|
        authorize entry, :validate?
        begin
          entry.validate!(validator: current_employee)
          validated_count += 1
        rescue ActiveRecord::RecordInvalid => e
          if e.record.errors[:base].any? { |msg| msg.include?('clôturée') }
            locked_count += 1
          end
        end
      end

      if validated_count > 0
        @team_member.notifications.create!(
          title: 'Heures validées',
          message: "Vos heures de travail pour la semaine du #{I18n.l(week_start, format: :short)} ont été validées par votre manager (#{validated_count} pointage#{'s' if validated_count > 1}).",
          notification_type: 'hours_validated'
        )
      end

      if locked_count > 0
        redirect_to manager_team_member_time_entries_path(@team_member),
                    alert: "#{locked_count} pointage#{'s' if locked_count > 1} ignoré#{'s' if locked_count > 1} : période clôturée."
      else
        redirect_to manager_team_member_time_entries_path(@team_member),
                    notice: "#{validated_count} pointage#{'s' if validated_count > 1} validé#{'s' if validated_count > 1}"
      end
    end

    def validate_entry
      @time_entry = policy_scope(TimeEntry).find(params[:id])
      authorize @time_entry, :validate?

      @time_entry.validate!(validator: current_employee)
      @time_entry.employee.notifications.create!(
        title: 'Pointage validé',
        message: "Votre pointage du #{I18n.l(@time_entry.worked_date, format: :long)} a été validé.",
        notification_type: 'hours_validated'
      )
      redirect_to manager_team_member_time_entries_path(@time_entry.employee),
                  notice: 'Pointage validé avec succès'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to manager_team_member_time_entries_path(@time_entry.employee),
                  alert: e.record.errors.full_messages.first || 'Impossible de valider ce pointage'
    end

    def reject_entry
      @time_entry = policy_scope(TimeEntry).find(params[:id])
      authorize @time_entry, :validate?

      @time_entry.reject!(rejector: current_employee, reason: params[:rejection_reason])
      @time_entry.employee.notifications.create!(
        title: 'Pointage refusé',
        message: "Votre pointage du #{I18n.l(@time_entry.worked_date, format: :long)} a été refusé par votre manager. Raison: #{params[:rejection_reason]}",
        notification_type: 'hours_rejected'
      )
      redirect_to manager_team_member_time_entries_path(@time_entry.employee),
                  notice: 'Pointage refusé'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to manager_team_member_time_entries_path(@time_entry.employee),
                  alert: e.record.errors.full_messages.first || 'Impossible de refuser ce pointage'
    end

    private

    def set_team_member
      @team_member = current_employee.team_members.find(params[:team_member_id])
    end

  end
end
