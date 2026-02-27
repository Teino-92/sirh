# frozen_string_literal: true

class OnboardingTemplatePolicy < ApplicationPolicy
  def index?
    user.hr_or_admin? || user.manager?
  end

  def show?
    user.hr_or_admin? || user.manager?
  end

  def create?
    user.hr_or_admin?
  end

  def new?
    create?
  end

  def update?
    user.hr_or_admin?
  end

  def edit?
    update?
  end

  def destroy?
    user.hr_or_admin?
  end

  class Scope < Scope
    def resolve
      scope.where(organization: user.organization).active
    end
  end
end
