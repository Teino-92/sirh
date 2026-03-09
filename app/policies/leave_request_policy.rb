# frozen_string_literal: true

class LeaveRequestPolicy < ApplicationPolicy
  include PlanGated

  def index?
    sirh_plan?
  end

  def show?
    sirh_plan? && (owner? || manager_of_owner? || hr_admin?)
  end

  def create?
    sirh_plan?
  end

  def new?
    create?
  end

  def update?
    sirh_plan? && owner? && record.pending?
  end

  def edit?
    update?
  end

  def destroy?
    false # Cannot delete leave requests
  end

  def approve?
    sirh_plan? && (hr_admin? || (manager_of_owner? && managers_can_approve?))
  end

  def reject?
    sirh_plan? && (hr_admin? || (manager_of_owner? && managers_can_approve?))
  end

  def reject_form?
    reject?
  end

  def cancel?
    sirh_plan? && owner? && record.status != "rejected"
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

  def managers_can_approve?
    value = record.employee.organization.group_policies.fetch('manager_can_approve_leave', true)
    ActiveRecord::Type::Boolean.new.cast(value) != false
  end
end
