# frozen_string_literal: true

class ObjectiveTaskPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.manager?
        scope.joins(:objective).where(objectives: { manager_id: user.id })
      else
        scope.where(assigned_to: user)
      end
    end
  end

  def create?
    user.manager? && record.objective.manager == user
  end

  def destroy?
    user.manager? && record.objective.manager == user && !record.validated?
  end

  def complete?
    user == record.assigned_to && !record.validated?
  end

  def validate_task?
    user.manager? && record.objective.manager == user && record.done?
  end
end
