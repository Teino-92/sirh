class TrainingAssignmentPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.hr_or_admin?
        scope.all
      elsif user.manager?
        scope.for_manager(user).or(scope.for_employee(user))
      else
        scope.for_employee(user)
      end
    end
  end

  def create?
    user.manager? || user.hr_or_admin?
  end

  def update?
    user.hr_or_admin? || record.assigned_by == user
  end

  def destroy?
    user.hr_or_admin? || record.assigned_by == user
  end

  def complete?
    record.employee == user || user.hr_or_admin? || record.assigned_by == user
  end
end
