# frozen_string_literal: true

module Admin
  class PayrollPeriodsController < BaseController
    before_action :set_payroll_period, only: [:destroy]

    # POST /admin/payroll/payroll_periods
    def create
      authorize PayrollPeriod, :create?

      period = Date.strptime(params[:period], '%Y-%m').beginning_of_month
      pp = current_employee.organization.payroll_periods.build(
        period:    period,
        locked_at: Time.current,
        locked_by: current_employee,
        notes:     params[:notes].presence
      )

      if pp.save
        redirect_to admin_payroll_path,
                    notice: "Période #{period.strftime('%B %Y')} clôturée."
      else
        redirect_to admin_payroll_path,
                    alert: pp.errors.full_messages.first
      end
    rescue ArgumentError
      redirect_to admin_payroll_path, alert: "Période invalide."
    end

    # DELETE /admin/payroll/payroll_periods/:id
    def destroy
      authorize @payroll_period, :destroy?
      period_label = @payroll_period.period.strftime('%B %Y')
      @payroll_period.destroy!
      redirect_to admin_payroll_path,
                  notice: "Période #{period_label} rouverte."
    end

    private

    def set_payroll_period
      @payroll_period = current_employee.organization.payroll_periods.find(params[:id])
    end
  end
end
