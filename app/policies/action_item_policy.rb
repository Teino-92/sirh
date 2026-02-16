class ActionItemPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.hr_or_admin?
        scope.joins(:one_on_one).where(one_on_ones: { organization_id: user.organization_id })
      elsif user.manager?
        scope.joins(:one_on_one).where(one_on_ones: { manager: user })
             .or(scope.where(responsible: user))
      else
        scope.where(responsible: user)
      end
    end
  end

  def create?
    record.one_on_one.manager == user || user.hr_or_admin?
  end

  def update?
    record.responsible == user || record.one_on_one.manager == user || user.hr_or_admin?
  end

  def complete?
    update?
  end
end
