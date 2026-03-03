# frozen_string_literal: true

class TrialPeriodDecisionPolicy < ApplicationPolicy
  # record is the Employee whose trial period is being decided

  def confirm?
    manage?
  end

  def renew?
    manage?
  end

  def terminate?
    manage?
  end

  private

  def manage?
    user.hr_or_admin? || user == record.manager
  end
end
