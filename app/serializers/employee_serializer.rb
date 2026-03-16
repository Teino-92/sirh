# frozen_string_literal: true

class EmployeeSerializer
  def initialize(employee, include_salary: false, current_employee: nil)
    @employee         = employee
    @include_salary   = include_salary
    @current_employee = current_employee
  end

  def as_json
    data = {
      id:         @employee.id,
      full_name:  @employee.full_name,
      first_name: @employee.first_name,
      last_name:  @employee.last_name,
      email:      @employee.email,
      role:       @employee.role,
      department: @employee.department,
      job_title:  @employee.job_title,
      start_date: @employee.start_date,
      cadre:      @employee.cadre?
    }

    if @include_salary && @current_employee&.hr_or_admin?
      data[:gross_salary_cents]    = @employee.gross_salary_cents
      data[:variable_pay_cents]    = @employee.variable_pay_cents
      data[:employer_charges_rate] = @employee.employer_charges_rate
    end

    data
  end
end
