# frozen_string_literal: true

class OrgMergeInvitationPolicy < ApplicationPolicy
  def index?   = user.hr_or_admin? && user.organization.sirh?
  def new?     = user.hr_or_admin? && user.organization.sirh?
  def create?  = user.hr_or_admin? && user.organization.sirh?
  def destroy? = user.hr_or_admin? && record.target_organization_id == user.organization_id

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(target_organization_id: user.organization_id)
    end
  end
end
