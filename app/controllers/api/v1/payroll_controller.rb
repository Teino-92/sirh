# frozen_string_literal: true

module Api
  module V1
    # Payroll summary API — HR/admin only.
    # Salary figures and payroll calculations are sensitive; no data is exposed
    # to employee-level or manager-level tokens.
    #
    # GET /api/v1/payroll/employees
    #   Returns paginated list of employees with salary + payroll summary for the period.
    #   Params:
    #     period [String]  YYYY-MM  (default: current month)
    #     page   [Integer] (default: 1)
    #     per_page [Integer] max 100 (default: 25)
    #
    # GET /api/v1/payroll/employees/:id
    #   Returns payroll detail for a single employee.
    #   Params:
    #     period [String]  YYYY-MM  (default: current month)
    #
    # GET /api/v1/payroll/summary
    #   Returns org-level payroll KPIs for the period (mass salariale, headcount, etc.)
    #   Params:
    #     period [String]  YYYY-MM  (default: current month)
    class PayrollController < BaseController
      before_action :authorize_hr!
      before_action :set_period

      # GET /api/v1/payroll/employees
      def employees
        base = current_employee.organization.employees.active
                               .includes(:work_schedule)
                               .order(:last_name, :first_name)

        per = (params[:per_page].presence&.to_i || 25).clamp(1, 100)
        paginated = base.page(params[:page]).per(per)

        employee_ids = paginated.map(&:id)
        te_by_emp    = preload_time_entries(employee_ids)
        lr_by_emp    = preload_leave_requests(employee_ids)

        rows = paginated.map do |emp|
          payroll_employee_payload(
            emp,
            time_entries:   te_by_emp[emp.id]  || [],
            leave_requests: lr_by_emp[emp.id]  || []
          )
        end

        render json: {
          data:       rows,
          period:     @period.strftime('%Y-%m'),
          meta:       pagination_meta(paginated)
        }
      end

      # GET /api/v1/payroll/employees/:id
      def employee_detail
        emp = current_employee.organization.employees.includes(:work_schedule).find(params[:id])

        calc = Payroll::PayrollCalculatorService.new(emp, @period).call

        render json: {
          data:   payroll_employee_payload(emp, time_entries: nil, leave_requests: nil, calc: calc),
          period: @period.strftime('%Y-%m')
        }
      end

      # GET /api/v1/payroll/summary
      def summary
        org        = current_employee.organization
        employees  = org.employees.active

        headcount          = employees.count
        total_gross        = employees.sum('gross_salary_cents + variable_pay_cents') / 100.0
        total_employer     = employees.sum('(gross_salary_cents + variable_pay_cents) * employer_charges_rate') / 100.0
        average_gross      = headcount > 0 ? total_gross / headcount : 0.0

        by_contract = employees.group(:contract_type)
                               .sum('gross_salary_cents + variable_pay_cents')
                               .transform_values { |c| c / 100.0 }

        by_department = employees.where.not(department: [nil, ''])
                                 .group(:department)
                                 .sum('gross_salary_cents + variable_pay_cents')
                                 .transform_values { |c| c / 100.0 }

        month_start  = @period
        month_end    = @period.end_of_month
        leave_cost   = approved_leave_cost(org, month_start, month_end, average_gross)

        render json: {
          period:           @period.strftime('%Y-%m'),
          headcount:        headcount,
          total_gross:      total_gross.round(2),
          total_employer:   total_employer.round(2),
          average_gross:    average_gross.round(2),
          total_annual:     (total_gross * 12).round(2),
          by_contract:      by_contract,
          by_department:    by_department,
          leave_cost_estimate: leave_cost.round(2)
        }
      end

      private

      def set_period
        if params[:period].present?
          @period = Date.strptime(params[:period], '%Y-%m').beginning_of_month
        else
          @period = Date.current.beginning_of_month
        end
      rescue ArgumentError
        render json: { error: "Paramètre 'period' invalide. Format attendu : YYYY-MM." },
               status: :bad_request
      end

      def preload_time_entries(employee_ids)
        TimeEntry
          .where(employee_id: employee_ids)
          .validated
          .where('clock_in >= ? AND clock_in < ?', @period, @period.next_month)
          .group_by(&:employee_id)
      end

      def preload_leave_requests(employee_ids)
        LeaveRequest
          .where(employee_id: employee_ids)
          .where(status: %w[approved auto_approved])
          .where('start_date <= ? AND end_date >= ?', @period.end_of_month, @period)
          .group_by(&:employee_id)
      end

      def payroll_employee_payload(emp, time_entries:, leave_requests:, calc: nil)
        calc ||= Payroll::PayrollCalculatorService.new(
          emp, @period,
          preloaded_time_entries:   time_entries,
          preloaded_leave_requests: leave_requests
        ).call

        {
          id:                emp.id,
          full_name:         emp.full_name,
          first_name:        emp.first_name,
          last_name:         emp.last_name,
          department:        emp.department,
          job_title:         emp.job_title,
          contract_type:     emp.contract_type,
          cadre:             emp.cadre?,
          part_time_rate:    emp.part_time_rate&.to_f || 1.0,
          gross_salary:      emp.gross_salary.round(2),
          variable_pay:      emp.variable_pay.round(2),
          employer_cost:     emp.total_employer_cost.round(2),
          payroll: {
            base_salary:       calc[:base_salary],
            worked_hours:      calc[:worked_hours],
            contractual_hours: calc[:contractual_hours],
            overtime_25:       calc[:overtime_25],
            overtime_50:       calc[:overtime_50],
            overtime_bonus:    calc[:overtime_bonus],
            leave_days_cp:     calc[:leave_days_cp],
            leave_days_rtt:    calc[:leave_days_rtt],
            leave_days_sick:   calc[:leave_days_sick],
            leave_deduction:   calc[:leave_deduction],
            gross_total:       calc[:gross_total],
            note:              calc[:note]
          }
        }
      end

      def approved_leave_cost(org, month_start, month_end, average_gross)
        total_days = LeaveRequest
          .where(organization_id: org.id)
          .where(status: %w[approved auto_approved])
          .where('start_date <= ? AND end_date >= ?', month_end, month_start)
          .sum(:days_count)
          .to_f

        avg_daily = average_gross / 22.0
        total_days * avg_daily
      end
    end
  end
end
