# frozen_string_literal: true

module Admin
  class OnboardingTemplateTasksController < BaseController
    before_action :set_template
    before_action :set_task, only: [:edit, :update, :destroy]

    def new
      @task = @template.onboarding_template_tasks.build
      authorize @template, policy_class: OnboardingTemplatePolicy
    end

    def create
      @task = @template.onboarding_template_tasks.build(task_params)
      @task.organization = current_employee.organization
      authorize @template, policy_class: OnboardingTemplatePolicy

      if @task.save
        redirect_to admin_onboarding_template_path(@template),
                    notice: 'Étape ajoutée.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @task.update(task_params)
        redirect_to admin_onboarding_template_path(@template),
                    notice: 'Étape mise à jour.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @task.destroy
      redirect_to admin_onboarding_template_path(@template),
                  notice: 'Étape supprimée.'
    end

    private

    def set_template
      @template = current_employee.organization.onboarding_templates.find(params[:onboarding_template_id])
    end

    def set_task
      @task = @template.onboarding_template_tasks.find(params[:id])
      authorize @template, policy_class: OnboardingTemplatePolicy
    end

    def task_params
      params.require(:onboarding_template_task).permit(
        :title, :description, :assigned_to_role,
        :due_day_offset, :task_type, :position,
        metadata: {}
      )
    end
  end
end
