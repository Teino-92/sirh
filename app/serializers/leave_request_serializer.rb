# frozen_string_literal: true

class LeaveRequestSerializer
  def initialize(request, include_employee: false)
    @request          = request
    @include_employee = include_employee
  end

  def as_json
    data = {
      id:              @request.id,
      leave_type:      @request.leave_type,
      leave_type_name: LeaveBalance.leave_type_name(@request.leave_type),
      start_date:      @request.start_date,
      end_date:        @request.end_date,
      days_count:      @request.days_count,
      status:          @request.status,
      reason:          @request.reason,
      approved_at:     @request.approved_at,
      created_at:      @request.created_at
    }

    if @include_employee
      data[:employee] = {
        id:         @request.employee.id,
        full_name:  @request.employee.full_name,
        department: @request.employee.department
      }
    end

    if @request.approved_by
      data[:approved_by] = {
        id:        @request.approved_by.id,
        full_name: @request.approved_by.full_name
      }
    end

    data
  end
end
