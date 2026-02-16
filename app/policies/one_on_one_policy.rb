class OneOnOnePolicy < ApplicationPolicy
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
    record.manager == user || user.hr_or_admin?
  end

  def destroy?
    record.manager == user || user.hr_or_admin?
  end

  def complete?
    update?
  end
end
