# frozen_string_literal: true

# Processes RTT accrual for a single organization for a given week.
# Enqueued by RttAccrualDispatcherJob — one instance per org, runs in parallel.
# Idempotent: LeaveBalance.find_or_create_by! prevents double creation.
class OrganizationRttAccrualJob < ApplicationJob
  queue_as :accruals

  discard_on ActiveRecord::RecordNotFound

  def perform(organization_id, week_start_date)
    organization = Organization.find(organization_id)
    week_start   = week_start_date.to_date
    week_end     = week_start.end_of_week

    ActsAsTenant.with_tenant(organization) do
      Rails.logger.info "[OrgRttAccrualJob] #{organization.name} — week #{week_start}/#{week_end}"

      active_employees = Employee.where('end_date IS NULL OR end_date > ?', week_start)

      active_employees.find_each do |employee|
        process_employee(employee, organization, week_start, week_end)
      rescue => e
        Rails.logger.error "[OrgRttAccrualJob] Employee #{employee.id} failed: #{e.message}"
      end
    end

    Rails.logger.info "[OrgRttAccrualJob] #{organization.name} — done"
  end

  private

  def process_employee(employee, organization, week_start, week_end)
    total_minutes = TimeEntry.where(employee: employee, organization: organization)
                             .where('DATE(clock_in) BETWEEN ? AND ?', week_start, week_end)
                             .completed
                             .sum(:duration_minutes)
    total_hours   = total_minutes / 60.0
    return if total_hours.zero?

    engine          = LeaveManagement::Services::LeavePolicyEngine.new(employee)
    rtt_threshold   = engine.get_setting(:rtt_calculation_threshold)
    overtime_hours  = [total_hours - rtt_threshold, 0].max
    return if overtime_hours.zero?

    rtt_days = (overtime_hours / 7.0).round(2)

    ActiveRecord::Base.transaction do
      rtt_balance = LeaveBalance.find_or_create_by!(
        employee: employee, organization: organization, leave_type: 'RTT'
      ) { |b| b.balance = 0; b.accrued_this_year = 0; b.used_this_year = 0 }

      rtt_balance.balance          += rtt_days
      rtt_balance.accrued_this_year += rtt_days
      rtt_balance.save!

      Rails.logger.info "[OrgRttAccrualJob] ✓ #{employee.email}: +#{rtt_days} RTT"
    end
  end
end
