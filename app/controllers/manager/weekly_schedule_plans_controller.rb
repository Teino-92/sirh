# frozen_string_literal: true
  # Authorization handled by authorize_manager! before_action

module Manager
  class WeeklySchedulePlansController < BaseController
    before_action :set_team_member
    before_action :set_weekly_plan, only: [:edit, :update, :destroy]

    def index
      # Calendar month navigation
      @current_date = params[:date]&.to_date || Date.current
      @start_date = @current_date.beginning_of_month.beginning_of_week(:monday)
      @end_date = @current_date.end_of_month.end_of_week(:sunday)

      # Get all plans for this calendar view
      @weekly_plans = policy_scope(WeeklySchedulePlan)
                                   .where(employee: @team_member)
                                   .where('week_start_date BETWEEN ? AND ?', @start_date, @end_date)
                                   .index_by(&:week_start_date)

      # Build calendar weeks
      @calendar_weeks = []
      current_date = @start_date
      while current_date <= @end_date
        @calendar_weeks << current_date
        current_date += 1.week
      end
    end

    def new
      week_start = params[:week_start]&.to_date || Date.current.next_week(:monday)
      @weekly_plan = @team_member.weekly_schedule_plans.build(week_start_date: week_start)
      authorize @weekly_plan
      @schedule_templates = load_schedule_templates

      # Pre-fill with default work schedule if available
      if @team_member.work_schedule
        @weekly_plan.schedule_pattern = @team_member.work_schedule.schedule_pattern
      end
    end

    def create
      @weekly_plan = @team_member.weekly_schedule_plans.build(weekly_plan_params)
      authorize @weekly_plan

      if @weekly_plan.save
        # Create notification for employee
        @team_member.notifications.create!(
          title: 'Planning hebdomadaire créé',
          message: "Votre manager a planifié votre semaine du #{l(@weekly_plan.week_start_date, format: :short)} au #{l(@weekly_plan.week_end_date, format: :short)}",
          notification_type: 'schedule_created',
          related_type: 'WeeklySchedulePlan',
          related_id: @weekly_plan.id
        )

        redirect_to manager_team_member_weekly_schedule_plans_path(@team_member),
                    notice: "Planning créé pour la semaine du #{l(@weekly_plan.week_start_date, format: :short)}"
      else
        @schedule_templates = load_schedule_templates
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @weekly_plan
      @schedule_templates = load_schedule_templates
    end

    def update
      authorize @weekly_plan
      if @weekly_plan.update(weekly_plan_params)
        # Create notification for employee
        @team_member.notifications.create!(
          title: 'Planning hebdomadaire modifié',
          message: "Votre manager a modifié votre planning pour la semaine du #{l(@weekly_plan.week_start_date, format: :short)} au #{l(@weekly_plan.week_end_date, format: :short)}",
          notification_type: 'schedule_updated',
          related_type: 'WeeklySchedulePlan',
          related_id: @weekly_plan.id
        )

        redirect_to manager_team_member_weekly_schedule_plans_path(@team_member),
                    notice: 'Planning mis à jour'
      else
        @schedule_templates = load_schedule_templates
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @weekly_plan
      week_display = l(@weekly_plan.week_start_date, format: :short)
      @weekly_plan.destroy
      redirect_to manager_team_member_weekly_schedule_plans_path(@team_member),
                  notice: "Planning supprimé pour la semaine du #{week_display}"
    end

    private

    def set_team_member
      @team_member = current_employee.team_members.find(params[:team_member_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to manager_team_schedules_path, alert: 'Employé non trouvé dans votre équipe'
    end

    def set_weekly_plan
      @weekly_plan = @team_member.weekly_schedule_plans.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to manager_team_member_weekly_schedule_plans_path(@team_member),
                  alert: 'Planning non trouvé'
    end

    def weekly_plan_params
      params.require(:weekly_schedule_plan).permit(
        :week_start_date,
        :notes,
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
