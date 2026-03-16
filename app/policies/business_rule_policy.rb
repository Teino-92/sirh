# frozen_string_literal: true

class BusinessRulePolicy < ApplicationPolicy
  def index?   = user.hr_or_admin?
  def show?    = user.hr_or_admin?
  def create?  = user.hr_or_admin?
  def new?     = create?
  def update?  = user.hr_or_admin?
  def edit?    = update?
  def destroy? = user.admin?
  def toggle?  = user.hr_or_admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(organization: user.organization)
    end
  end
end
