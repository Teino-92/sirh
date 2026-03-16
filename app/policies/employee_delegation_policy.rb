# frozen_string_literal: true

class EmployeeDelegationPolicy < ApplicationPolicy
  include PlanGated

  def index?
    sirh_plan?
  end

  def new?
    create?
  end

  def create?
    sirh_plan? && (user.manager? || user.hr_or_admin?)
  end

  def destroy?
    sirh_plan? && (record.delegator_id == user.id || user.admin?)
  end

  class Scope
    def initialize(user, scope)
      @user  = user
      @scope = scope
    end

    def resolve
      scope.where(delegator: user).or(scope.where(delegatee: user))
    end

    private

    attr_reader :user, :scope
  end
end
