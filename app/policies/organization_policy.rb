# frozen_string_literal: true

class OrganizationPolicy < ApplicationPolicy
  def show?
    user.hr_or_admin? && user.organization_id == record.id
  end

  def update?
    user.admin? && user.organization_id == record.id
  end

  def edit?
    update?
  end
end
