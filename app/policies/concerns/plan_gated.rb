# frozen_string_literal: true

# Concern to gate features by organization plan.
# Include in any Pundit policy that needs to restrict access to SIRH-only features.
#
# Plans:
#   manager_os  — Manager OS product (onboarding, 1:1, objectives, training, evaluations)
#   sirh        — Full HRIS (+ time tracking, leave, scheduling, payroll)
#
# Usage in a policy:
#   include PlanGated
#
#   def index?
#     sirh_plan? && user.hr_or_admin?
#   end
module PlanGated
  # Returns true for both manager_os and sirh plans.
  def manager_os_plan?
    organization.plan.in?(%w[manager_os sirh])
  end

  # Returns true only for the full SIRH plan.
  def sirh_plan?
    organization.plan == "sirh"
  end

  private

  def organization
    # user is always a current_employee — organization is set via ActsAsTenant
    user.organization
  end
end
