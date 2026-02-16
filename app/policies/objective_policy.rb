class ObjectivePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.hr_or_admin?
        scope.all
      elsif user.manager?
        scope.where(manager: user)
             .or(scope.where(owner: user))
      else
        scope.where(owner: user)
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

  def complete?
    update?
  end
end
