# frozen_string_literal: true

class TimeEntryPolicy < ApplicationPolicy
  include PlanGated

  def index?
    sirh_plan? # Time tracking is SIRH only
  end

  def show?
    sirh_plan? && (owner? || manager_of_owner? || hr_admin?)
  end

  def create?
    sirh_plan? && owner?
  end

  def update?
    false # Employees cannot update time entries
  end

  def destroy?
    false # Employees cannot delete time entries
  end

  def clock_in?
    sirh_plan?
  end

  def clock_out?
    sirh_plan? && record.employee_id == user.id
  end

  def validate?
    sirh_plan? && (manager_of_owner? || hr_admin?)
  end

  def edit_as_admin?
    sirh_plan? && hr_admin?
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      return scope.none unless user.organization.sirh?

      if user.hr_or_admin?
        scope.all
      elsif user.manager?
        scope.where(employee_id: [user.id] + user.team_members.pluck(:id))
      else
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
