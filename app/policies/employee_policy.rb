# frozen_string_literal: true

class EmployeePolicy < ApplicationPolicy
  # Employee can view and edit their own profile
  def show?
    user == record
  end

  def update?
    user == record
  end

  def edit?
    update?
  end

  # Droit du travail français : confidentialité salariale stricte.
  # Seuls HR/admin et l'employé lui-même peuvent consulter un salaire.
  # Un manager n'a aucun droit sur le salaire de ses subordonnés.
  def see_salary?
    user.hr_or_admin? || user == record
  end

  class Scope < Scope
    def resolve
      # Employees can only see themselves
      # Managers can see their direct reports
      # HR/Admin can see all
      if user.hr_or_admin?
        scope.all
      elsif user.manager?
        scope.where(id: user.id).or(scope.where(manager_id: user.id))
      else
        scope.where(id: user.id)
      end
    end
  end
end
