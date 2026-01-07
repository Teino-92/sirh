# frozen_string_literal: true
  # Authorization handled by authorize_manager! before_action

module Manager
  class WorkSchedulesController < ApplicationController
    before_action :authenticate_employee!
    before_action :authorize_manager!
    before_action :set_team_member

    def new
      @work_schedule = @team_member.build_work_schedule
      authorize @work_schedule
      @schedule_templates = load_schedule_templates
    end

    def create
      @work_schedule = @team_member.build_work_schedule(work_schedule_params)
      authorize @work_schedule

      if @work_schedule.save
        # Create notification for employee
        @team_member.notifications.create!(
          title: 'Horaire de travail créé',
          message: "Votre manager a créé votre horaire de travail : #{@work_schedule.name} (#{@work_schedule.weekly_hours}h/semaine)",
          notification_type: 'schedule_created',
          related_type: 'WorkSchedule',
          related_id: @work_schedule.id
        )

        redirect_to manager_team_schedules_path, notice: "Horaire créé pour #{@team_member.full_name}"
      else
        @schedule_templates = load_schedule_templates
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @work_schedule = @team_member.work_schedule

      unless @work_schedule
        redirect_to new_manager_team_member_work_schedule_path(@team_member), alert: 'Horaire non trouvé'
        return
      end

      authorize @work_schedule
      @schedule_templates = load_schedule_templates
    end

    def update
      @work_schedule = @team_member.work_schedule
      authorize @work_schedule

      if @work_schedule.update(work_schedule_params)
        # Create notification for employee
        @team_member.notifications.create!(
          title: 'Horaire de travail modifié',
          message: "Votre manager a modifié votre horaire de travail : #{@work_schedule.name} (#{@work_schedule.weekly_hours}h/semaine)",
          notification_type: 'schedule_updated',
          related_type: 'WorkSchedule',
          related_id: @work_schedule.id
        )

        redirect_to manager_team_schedules_path, notice: "Horaire mis à jour pour #{@team_member.full_name}"
      else
        @schedule_templates = load_schedule_templates
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_team_member
      @team_member = current_employee.team_members.find(params[:team_member_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to manager_team_schedules_path, alert: 'Employé non trouvé dans votre équipe'
    end

    def authorize_manager!
      unless current_employee.manager?
        redirect_to dashboard_path, alert: 'Accès réservé aux managers'
      end
    end

    def work_schedule_params
      params.require(:work_schedule).permit(
        :name,
        :weekly_hours,
        schedule_pattern: [
          :monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday
        ]
      )
    end

    def load_schedule_templates
      {
        'full_time_35h' => {
          name: 'Temps plein 35h (9h-17h)',
          weekly_hours: 35,
          pattern: {
            'monday' => '09:00-17:00',
            'tuesday' => '09:00-17:00',
            'wednesday' => '09:00-17:00',
            'thursday' => '09:00-17:00',
            'friday' => '09:00-17:00',
            'saturday' => 'off',
            'sunday' => 'off'
          }
        },
        'full_time_39h' => {
          name: 'Temps plein 39h avec RTT (9h-18h)',
          weekly_hours: 39,
          pattern: {
            'monday' => '09:00-18:00',
            'tuesday' => '09:00-18:00',
            'wednesday' => '09:00-18:00',
            'thursday' => '09:00-18:00',
            'friday' => '09:00-18:00',
            'saturday' => 'off',
            'sunday' => 'off'
          }
        },
        'part_time_24h' => {
          name: 'Temps partiel 24h (3 jours)',
          weekly_hours: 24,
          pattern: {
            'monday' => '09:00-17:00',
            'tuesday' => '09:00-17:00',
            'wednesday' => '09:00-17:00',
            'thursday' => 'off',
            'friday' => 'off',
            'saturday' => 'off',
            'sunday' => 'off'
          }
        },
        'custom' => {
          name: 'Horaire personnalisé',
          weekly_hours: 35,
          pattern: {
            'monday' => '',
            'tuesday' => '',
            'wednesday' => '',
            'thursday' => '',
            'friday' => '',
            'saturday' => 'off',
            'sunday' => 'off'
          }
        }
      }
    end
  end
end
