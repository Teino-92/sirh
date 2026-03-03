# frozen_string_literal: true

class AuditLogPolicy < ApplicationPolicy
  def show?
    user.hr_or_admin?
  end
end
