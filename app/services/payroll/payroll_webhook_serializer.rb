# frozen_string_literal: true

module Payroll
  # Builds the JSON payload pushed to the Silae webhook for a locked period.
  #
  # Runs inside a background job — no current_employee context available.
  # Authorization was enforced at enqueue time.
  #
  # @param organization [Organization]
  # @param period       [Date]  any date in the target month
  class PayrollWebhookSerializer
    def initialize(organization, period)
      @org    = organization
      @period = period.beginning_of_month
    end

    def as_json
      employees = @org.employees.active
                      .includes(:work_schedule, :manager)
                      .order(:last_name, :first_name)

      employee_ids = employees.map(&:id)

      time_entries_by_employee   = preload_time_entries(employee_ids)
      leave_requests_by_employee = preload_leave_requests(employee_ids)

      {
        period:       @period.strftime('%Y-%m'),
        generated_at: Time.current.utc.iso8601,
        organization: { id: @org.id, name: @org.name },
        employees:    employees.map { |emp|
          serialize_employee(
            emp,
            time_entries:   time_entries_by_employee[emp.id]   || [],
            leave_requests: leave_requests_by_employee[emp.id] || []
          )
        }
      }
    end

    private

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

    def serialize_employee(emp, time_entries:, leave_requests:)
      calc = PayrollCalculatorService.new(
        emp, @period,
        preloaded_time_entries:   time_entries,
        preloaded_leave_requests: leave_requests
      ).call

      {
        id:                    emp.id,
        matricule:             emp.id.to_s,
        nir:                   emp.nir.to_s,
        last_name:             emp.last_name,
        first_name:            emp.first_name,
        birth_date:            emp.birth_date&.iso8601,
        birth_city:            emp.birth_city.to_s,
        birth_department:      emp.birth_department.to_s,
        nationality:           emp.nationality.to_s,
        iban:                  emp.iban.to_s,
        bic:                   emp.bic.to_s,
        contract_type:         emp.contract_type.to_s,
        convention_collective: emp.convention_collective.to_s,
        qualification:         emp.qualification.to_s,
        coefficient:           emp.coefficient.to_s,
        start_date:            emp.start_date&.iso8601,
        part_time_rate:        emp.part_time_rate || 1.0,
        gross_salary:          emp.gross_salary.to_f,
        variable_pay:          emp.variable_pay.to_f,
        contractual_hours:     calc[:contractual_hours].to_f,
        worked_hours:          calc[:worked_hours].to_f,
        overtime_25h:          calc[:overtime_25].to_f,
        overtime_50h:          calc[:overtime_50].to_f,
        leave_days: {
          CP:          calc[:leave_days_cp].to_f,
          RTT:         calc[:leave_days_rtt].to_f,
          Maladie:     calc[:leave_days_sick].to_f,
          "Sans solde" => calc[:leave_deduction].to_f
        },
        department:            emp.department.to_s,
        cadre:                 emp.cadre?,
        manager:               emp.manager&.full_name.to_s
      }
    end
  end
end
