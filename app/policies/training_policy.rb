class TrainingPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.hr_or_admin?
        scope.all
      else
        scope.active
      end
    end
  end

  def create?
    user.manager? || user.hr_or_admin?
  end

  def update?
    user.manager? || user.hr_or_admin?
  end

  def destroy?
    user.hr_or_admin?
  end

  def archive?
    user.manager? || user.hr_or_admin?
  end
end
