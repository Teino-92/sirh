# frozen_string_literal: true

class LeaveRequestPolicy < ApplicationPolicy
  def index?
    true # Everyone can see leave requests
  end

  def show?
    owner? || manager_of_owner? || hr_admin?
  end

  def create?
    true # Any employee can request leave
  end

  def new?
    create?
  end

  def update?
    owner? && record.pending? # Can only update pending requests
  end

  def edit?
    update?
  end

  def destroy?
    false # Cannot delete leave requests
  end

  def approve?
    manager_of_owner? || hr_admin?
  end

  def reject?
    manager_of_owner? || hr_admin?
  end

  def cancel?
    owner? && !record.rejected? # Can cancel unless rejected
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
        # Managers see their team's requests + their own
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
