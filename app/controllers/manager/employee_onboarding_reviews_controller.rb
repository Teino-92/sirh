# frozen_string_literal: true

module Manager
  class EmployeeOnboardingReviewsController < BaseController

    def new
      @employee_onboarding = current_organization.employee_onboardings.find(params[:employee_onboarding_id])
      authorize @employee_onboarding, :update?
      @review = OnboardingReview.new(employee_onboarding: @employee_onboarding,
                                     reviewer_type: 'manager', review_day: 30)
    end

    def create
      @employee_onboarding = current_organization.employee_onboardings.find(params[:employee_onboarding_id])
      authorize @employee_onboarding, :update?

      @review = OnboardingReview.new(
        employee_onboarding: @employee_onboarding,
        organization:        current_organization,
        reviewer_type:       'manager',
        review_day:          30,
        manager_feedback_json: manager_feedback_params
      )

      if @review.save
        EmployeeOnboardingScoreRefreshJob.perform_later(@employee_onboarding.id)
        redirect_to manager_employee_onboarding_path(@employee_onboarding), notice: 'Feedback enregistré.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def manager_feedback_params
      params.require(:onboarding_review).permit(
        :integration_level, :strengths, :risk_signals
      ).to_h
    end
  end
end
