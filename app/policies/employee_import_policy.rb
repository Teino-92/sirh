# frozen_string_literal: true

class EmployeeImportPolicy < ApplicationPolicy
  def new?
    user.hr_or_admin?
  end

  def create?
    user.hr_or_admin?
  end
end
