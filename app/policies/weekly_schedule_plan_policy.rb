# frozen_string_literal: true

class WeeklySchedulePlanPolicy < ApplicationPolicy
  def index?
    true # Everyone can see schedules
  end

  def show?
    owner? || manager_of_owner? || hr_admin?
  end

  def create?
    manager_of_owner? || hr_admin?
  end

  def new?
    create?
  end

  def update?
    manager_of_owner? || hr_admin?
  end

  def edit?
    update?
  end

  def destroy?
    manager_of_owner? || hr_admin?
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if user.hr_or_admin?
        scope.all
      elsif user.manager?
        # Managers see their team's schedules + their own
        scope.where(employee_id: [user.id] + user.team_member_ids)
      else
        # Employees see only their own
        scope.where(employee_id: user.id)
      end
    end
  end

  private

  def owner?
    record.employee_id == user.id
  end

  def manager_of_owner?
    user.manager? && user.team_member_ids.include?(record.employee_id)
  end

  def hr_admin?
    user.hr_or_admin?
  end
end
