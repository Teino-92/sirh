# frozen_string_literal: true

class WorkSchedulePolicy < ApplicationPolicy
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
