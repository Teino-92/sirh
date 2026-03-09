# frozen_string_literal: true

class LeaveBalancePolicy < ApplicationPolicy
  include PlanGated

  def index?
    sirh_plan?
  end

  def show?
    sirh_plan? && (record.employee_id == user.id || user.manager? || user.hr_or_admin?)
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
      else
        scope.where(employee_id: user.id)
      end
    end
  end
end
