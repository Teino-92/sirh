# frozen_string_literal: true

class EmployeeOnboardingPolicy < ApplicationPolicy
  def index?
    hr_admin? || user.manager?
  end

  def show?
    hr_admin? || manager_of_employee? || own_onboarding?
  end

  def create?
    hr_admin? || user.manager?
  end

  def new?
    create?
  end

  def update?
    hr_admin? || manager_of_employee?
  end

  def edit?
    update?
  end

  def destroy?
    hr_admin?
  end

  class Scope < Scope
    def resolve
      if user.hr_or_admin?
        scope.all
      elsif user.manager?
        scope.where(manager_id: user.id)
             .or(scope.where(employee_id: user.id))
      else
        scope.where(employee_id: user.id)
      end
    end
  end

  private

  def hr_admin?
    user.hr_or_admin?
  end

  def manager_of_employee?
    user.manager? && record.manager_id == user.id
  end

  def own_onboarding?
    record.employee_id == user.id
  end
end
