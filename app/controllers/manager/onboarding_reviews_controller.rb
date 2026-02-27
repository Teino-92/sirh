# frozen_string_literal: true

module Manager
  class OnboardingReviewsController < BaseController

    def new
      @onboarding = current_employee.organization.onboardings.find(params[:onboarding_id])
      authorize @onboarding, :update?
      @review = OnboardingReview.new(onboarding: @onboarding, reviewer_type: 'manager', review_day: 30)
    end

    def create
      @onboarding = current_employee.organization.onboardings.find(params[:onboarding_id])
      authorize @onboarding, :update?

      @review = OnboardingReview.new(
        onboarding:              @onboarding,
        organization:            current_employee.organization,
        reviewer_type:           'manager',
        review_day:              30,
        manager_feedback_json:   manager_feedback_params
      )

      if @review.save
        OnboardingScoreRefreshJob.perform_later(@onboarding.id)
        redirect_to manager_onboarding_path(@onboarding), notice: 'Feedback enregistré.'
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
