# frozen_string_literal: true

class ObjectiveTaskPolicy < ApplicationPolicy
  def create?
    user.manager? && record.objective.manager == user
  end

  def destroy?
    return false if record.validated?
    user.manager? && record.objective.manager == user
  end

  def complete?
    return false if record.validated?
    user == record.assigned_to
  end

  def validate_task?
    return false unless record.done?
    user.manager? && record.objective.manager == user
  end
end
