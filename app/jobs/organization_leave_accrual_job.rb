# frozen_string_literal: true

# Processes CP accrual for a single organization.
# Enqueued by LeaveAccrualDispatcherJob — one instance per org, runs in parallel.
# Idempotent: safe to retry if it fails mid-way (LeaveBalance.find_or_create_by!).
class OrganizationLeaveAccrualJob < ApplicationJob
  queue_as :accruals

  discard_on ActiveRecord::RecordNotFound

  def perform(organization_id)
    organization = Organization.find(organization_id)

    ActsAsTenant.with_tenant(organization) do
      Rails.logger.info "[OrgLeaveAccrualJob] #{organization.name} — start"

      active_employees = Employee.where('end_date IS NULL OR end_date > ?', Date.current)

      active_employees.find_each do |employee|
        process_employee(employee, organization)
      rescue => e
        Rails.logger.error "[OrgLeaveAccrualJob] Employee #{employee.id} failed: #{e.message}"
      end
    end

    Rails.logger.info "[OrgLeaveAccrualJob] #{organization.name} — done"
  end

  private

  def process_employee(employee, organization)
    ActiveRecord::Base.transaction do
      engine          = LeavePolicyEngine.new(employee)
      monthly_accrual = engine.get_setting(:cp_acquisition_rate)

      if employee.respond_to?(:part_time_ratio) && employee.part_time_ratio.present? && employee.part_time_ratio < 1.0
        monthly_accrual *= employee.part_time_ratio
      end

      cp_balance = LeaveBalance.find_or_create_by!(
        employee: employee, organization: organization, leave_type: 'CP'
      ) { |b| b.balance = 0; b.accrued_this_year = 0; b.used_this_year = 0 }

      max_annual      = engine.get_setting(:cp_max_annual)
      remaining_cap   = [max_annual - cp_balance.balance, 0].max
      monthly_accrual = [monthly_accrual, remaining_cap].min

      expiry_month    = engine.get_setting(:cp_expiry_month)
      expiry_day      = engine.get_setting(:cp_expiry_day)
      cp_balance.balance          += monthly_accrual
      cp_balance.accrued_this_year += monthly_accrual
      cp_balance.expires_at        = Date.new(Date.current.year + 1, expiry_month, expiry_day)
      cp_balance.save!

      Rails.logger.info "[OrgLeaveAccrualJob] ✓ #{employee.email}: +#{monthly_accrual.round(2)} CP"
    end
  end
end
