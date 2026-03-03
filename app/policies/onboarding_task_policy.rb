# frozen_string_literal: true

class OnboardingTaskPolicy < ApplicationPolicy
  def update?
    hr_admin? || manager_of_onboarding?
  end

  class Scope < Scope
    def resolve
      if user.hr_or_admin?
        scope.all
      elsif user.manager?
        scope.joins(:employee_onboarding)
             .where(employee_onboardings: { manager_id: user.id })
      else
        scope.joins(:employee_onboarding)
             .where(employee_onboardings: { employee_id: user.id })
      end
    end
  end

  private

  def hr_admin?
    user.hr_or_admin?
  end

  def manager_of_onboarding?
    user.manager? && record.employee_onboarding.manager_id == user.id
  end
end
