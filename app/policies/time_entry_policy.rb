# frozen_string_literal: true

class TimeEntryPolicy < ApplicationPolicy
  def index?
    true # Everyone can see their own time entries
  end

  def show?
    owner? || manager_of_owner? || hr_admin?
  end

  def create?
    owner? # Only the employee can create their own entries
  end

  def update?
    false # Employees cannot update time entries
  end

  def destroy?
    false # Employees cannot delete time entries
  end

  def clock_in?
    user.present? # Any authenticated user can clock in
  end

  def clock_out?
    user.present? && record.employee_id == user.id
  end

  def validate?
    manager_of_owner? || hr_admin?
  end

  def edit_as_admin?
    hr_admin?
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
        # Managers can see their team's entries + their own
        scope.where(employee_id: [user.id] + user.team_members.pluck(:id))
      else
        # Employees can only see their own
        scope.where(employee_id: user.id)
      end
    end
  end

  private

  def owner?
    record.employee_id == user.id
  end

  def manager_of_owner?
    user.manager? && user.team_members.pluck(:id).include?(record.employee_id)
  end

  def hr_admin?
    user.hr_or_admin?
  end
end
