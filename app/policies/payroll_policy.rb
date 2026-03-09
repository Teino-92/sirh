# frozen_string_literal: true

# Policy for admin payroll dashboard.
# The "record" is a symbol (:payroll) — not a persisted resource.
class PayrollPolicy < ApplicationPolicy
  include PlanGated

  def show?
    sirh_plan? && user.hr_or_admin?
  end

  def export?
    sirh_plan? && user.hr_or_admin?
  end

  def export_silae?
    sirh_plan? && user.hr_or_admin?
  end

  def push_silae?
    sirh_plan? && user.hr_or_admin?
  end
end
