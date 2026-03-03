# frozen_string_literal: true

# Policy for admin payroll dashboard.
# The "record" is a symbol (:payroll) — not a persisted resource.
class PayrollPolicy < ApplicationPolicy
  def show?
    user.hr_or_admin?
  end

  def export?
    user.hr_or_admin?
  end

  def export_silae?
    user.hr_or_admin?
  end

  def push_silae?
    user.hr_or_admin?
  end
end
