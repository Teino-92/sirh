# frozen_string_literal: true

module Api
  module V1
    module Concerns
      # Thin façade — delegates to standalone serializers in app/serializers/.
      # Controllers call these helpers unchanged; serializers can be used
      # independently in jobs, mailers, and exports.
      module Serializable
        def serialize_employee(employee, include_salary: false)
          EmployeeSerializer.new(
            employee,
            include_salary:   include_salary,
            current_employee: current_employee
          ).as_json
        end

        def serialize_time_entry(entry)
          TimeEntrySerializer.new(entry).as_json
        end

        def serialize_leave_request(request, include_employee: false)
          LeaveRequestSerializer.new(request, include_employee: include_employee).as_json
        end

        def serialize_leave_balance(balance)
          LeaveBalanceSerializer.new(balance).as_json
        end

        def serialize_work_schedule(schedule)
          WorkScheduleSerializer.new(schedule).as_json
        end
      end
    end
  end
end
