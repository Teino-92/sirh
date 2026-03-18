# frozen_string_literal: true

class OnboardingTemplatePolicy < ApplicationPolicy
  def index?
    user.hr_or_admin? || user.manager?
  end

  def show?
    user.hr_or_admin? || user.manager?
  end

  def create?
    user.hr_or_admin? || (user.manager? && org.manager_os?)
  end

  def new?
    create?
  end

  def update?
    user.hr_or_admin? || (user.manager? && org.manager_os?)
  end

  def edit?
    update?
  end

  def destroy?
    user.hr_or_admin? || (user.manager? && org.manager_os?)
  end

  private

  def org
    record.organization || user.organization
  end

  class Scope < Scope
    def resolve
      scope.where(organization_id: user.organization_id).active
    end
  end
end
