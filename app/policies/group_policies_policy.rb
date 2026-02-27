# frozen_string_literal: true

class GroupPoliciesPolicy < ApplicationPolicy
  # record is the Organization instance

  def edit?
    user.hr_or_admin?
  end

  def update?
    user.hr_or_admin?
  end

  def preview?
    user.hr_or_admin?
  end
end
