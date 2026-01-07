class BackfillOrganizationIds < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    # TimeEntry - Copier organization_id depuis employee
    execute <<-SQL.squish
      UPDATE time_entries
      SET organization_id = employees.organization_id
      FROM employees
      WHERE time_entries.employee_id = employees.id
      AND time_entries.organization_id IS NULL
    SQL

    # LeaveRequest - Copier organization_id depuis employee
    execute <<-SQL.squish
      UPDATE leave_requests
      SET organization_id = employees.organization_id
      FROM employees
      WHERE leave_requests.employee_id = employees.id
      AND leave_requests.organization_id IS NULL
    SQL

    # LeaveBalance - Copier organization_id depuis employee
    execute <<-SQL.squish
      UPDATE leave_balances
      SET organization_id = employees.organization_id
      FROM employees
      WHERE leave_balances.employee_id = employees.id
      AND leave_balances.organization_id IS NULL
    SQL

    # WorkSchedule - Copier organization_id depuis employee
    execute <<-SQL.squish
      UPDATE work_schedules
      SET organization_id = employees.organization_id
      FROM employees
      WHERE work_schedules.employee_id = employees.id
      AND work_schedules.organization_id IS NULL
    SQL

    # WeeklySchedulePlan - Copier organization_id depuis employee
    execute <<-SQL.squish
      UPDATE weekly_schedule_plans
      SET organization_id = employees.organization_id
      FROM employees
      WHERE weekly_schedule_plans.employee_id = employees.id
      AND weekly_schedule_plans.organization_id IS NULL
    SQL

    # Notification - Copier organization_id depuis employee
    execute <<-SQL.squish
      UPDATE notifications
      SET organization_id = employees.organization_id
      FROM employees
      WHERE notifications.employee_id = employees.id
      AND notifications.organization_id IS NULL
    SQL
  end

  def down
    # Pas de rollback - les données restent
  end
end
