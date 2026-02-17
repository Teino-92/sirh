class EvaluationPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.hr_or_admin?
        scope.all
      elsif user.manager?
        scope.where(manager: user)
             .or(scope.where(employee: user))
      else
        scope.where(employee: user)
      end
    end
  end

  def create?
    user.manager? || user.hr_or_admin?
  end

  def update?
    user.hr_or_admin? || record.manager == user
  end

  def destroy?
    user.hr_or_admin? || record.manager == user
  end

  def submit_self_review?
    record.employee == user && record.employee_review_pending?
  end

  def submit_manager_review?
    (user.hr_or_admin? || record.manager == user) && record.manager_review_pending?
  end

  def complete?
    user.hr_or_admin? || record.manager == user
  end
end
