# frozen_string_literal: true

module Api
  module V1
    module Concerns
      # Shared JSON serialization helpers for API V1 controllers.
      # Centralises field selection so no sensitive data (salary, tokens) leaks.
      module Serializable
        def serialize_employee(employee, include_salary: false)
          data = {
            id:         employee.id,
            full_name:  employee.full_name,
            first_name: employee.first_name,
            last_name:  employee.last_name,
            email:      employee.email,
            role:       employee.role,
            department: employee.department,
            job_title:  employee.job_title,
            start_date: employee.start_date,
            cadre:      employee.cadre?
          }

          if include_salary && current_employee.hr_or_admin?
            data[:gross_salary_cents]    = employee.gross_salary_cents
            data[:variable_pay_cents]    = employee.variable_pay_cents
            data[:employer_charges_rate] = employee.employer_charges_rate
          end

          data
        end

        def serialize_time_entry(entry)
          {
            id:               entry.id,
            clock_in:         entry.clock_in,
            clock_out:        entry.clock_out,
            duration_minutes: entry.duration_minutes,
            hours_worked:     entry.hours_worked,
            active:           entry.active?,
            overtime:         entry.overtime?,
            worked_date:      entry.worked_date,
            location:         entry.location
          }
        end

        def serialize_leave_request(request, include_employee: false)
          data = {
            id:             request.id,
            leave_type:     request.leave_type,
            leave_type_name: LeaveBalance.leave_type_name(request.leave_type),
            start_date:     request.start_date,
            end_date:       request.end_date,
            days_count:     request.days_count,
            status:         request.status,
            reason:         request.reason,
            approved_at:    request.approved_at,
            created_at:     request.created_at
          }

          if include_employee
            data[:employee] = {
              id:         request.employee.id,
              full_name:  request.employee.full_name,
              department: request.employee.department
            }
          end

          if request.approved_by
            data[:approved_by] = {
              id:        request.approved_by.id,
              full_name: request.approved_by.full_name
            }
          end

          data
        end

        def serialize_leave_balance(balance)
          {
            id:            balance.id,
            leave_type:    balance.leave_type,
            leave_type_name: LeaveBalance.leave_type_name(balance.leave_type),
            balance:       balance.balance,
            used_this_year: balance.used_this_year,
            accrued_this_year: balance.accrued_this_year,
            expires_at:    balance.expires_at,
            expiring_soon: balance.expiring_soon?
          }
        end

        def serialize_work_schedule(schedule)
          {
            id:               schedule.id,
            name:             schedule.name,
            weekly_hours:     schedule.weekly_hours,
            schedule_pattern: schedule.schedule_pattern
          }
        end
      end
    end
  end
end
