# frozen_string_literal: true

module Admin
  class EmployeesController < BaseController
    before_action :set_employee, only: [:show, :edit, :update, :destroy]

    def index
      @employees = current_employee.organization.employees
                                   .includes(:manager, avatar_attachment: :blob)

      # Search functionality
      if params[:q].present?
        search_term = "%#{params[:q]}%"
        @employees = @employees.where(
          "first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?",
          search_term, search_term, search_term
        )
      end

      @employees = @employees.order(last_name: :asc, first_name: :asc)
                            .page(params[:page])
                            .per(20)
    end

    def show
      authorize @employee, :see_salary?
      log_payroll_access if sensitive_payroll_data_stored?
    end

    def new
      @employee = Employee.new
      @employee.organization = current_employee.organization
    end

    def create
      @employee = Employee.new(employee_params)
      @employee.organization = current_employee.organization

      saved = ActiveRecord::Base.transaction do
        @employee.save!
        LeaveBalanceInitializer.new(@employee).initialize_balances
        true
      rescue ActiveRecord::RecordInvalid
        false
      end

      if saved
        respond_to do |format|
          format.html { redirect_to admin_employee_path(@employee), notice: 'Employé créé avec succès.' }
          format.turbo_stream
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream
        end
      end
    end

    def edit
      authorize @employee, :see_salary?
      log_payroll_access if sensitive_payroll_data_stored?
    end

    def update
      authorize @employee, :see_salary?
      attrs = employee_params
      # Merge settings so we don't clobber existing keys (e.g. 'active')
      if attrs[:settings].present?
        attrs = attrs.merge(settings: @employee.settings.merge(attrs[:settings].to_h))
      end
      if @employee.update(attrs)
        respond_to do |format|
          format.html { redirect_to admin_employee_path(@employee), notice: 'Employé mis à jour avec succès.' }
          format.turbo_stream
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream
        end
      end
    end

    def destroy
      @employee.destroy

      respond_to do |format|
        format.html { redirect_to admin_employees_path, notice: 'Employé supprimé avec succès.' }
        format.turbo_stream
      end
    end

    private

    def set_employee
      @employee = current_employee.organization.employees.find(params[:id])
    end

    # Checks presence of sensitive fields without decrypting — reads raw ciphertext column.
    def sensitive_payroll_data_stored?
      @employee.read_attribute_before_type_cast(:nir).present? ||
        @employee.read_attribute_before_type_cast(:iban).present?
    end

    def log_payroll_access
      PaperTrail::Version.create!(
        item_type:       'Employee',
        item_id:         @employee.id,
        event:           'payroll_data_viewed',
        whodunnit:       current_employee.id.to_s,
        organization_id: current_organization.id,
        object_changes:  { ip: request.remote_ip }.to_json
      )
    rescue StandardError => e
      Rails.logger.error("[AuditLog] payroll_data_viewed failed: #{e.message}")
    end

    def employee_params
      permitted = params.require(:employee).permit(
        :email,
        :password,
        :password_confirmation,
        :first_name,
        :last_name,
        :role,
        :contract_type,
        :start_date,
        :end_date,
        :department,
        :hr_perimeter_list,
        :job_title,
        :manager_id,
        :avatar,
        :address,
        :gross_salary_eur,
        :variable_pay_eur,
        :employer_charges_rate,
        # Payroll / DSN fields
        :nir,
        :nir_key,
        :birth_date,
        :birth_city,
        :birth_department,
        :birth_country,
        :nationality,
        :iban,
        :bic,
        :convention_collective,
        :qualification,
        :coefficient,
        :part_time_rate,
        :trial_period_end,
        :termination_date,
        :termination_reason,
        settings: [:cadre]
      )

      # Virtual euro fields → convert to cents for storage
      if permitted[:gross_salary_eur].present?
        permitted[:gross_salary_cents] = (permitted.delete(:gross_salary_eur).to_f * 100).round
      else
        permitted.delete(:gross_salary_eur)
      end
      if permitted[:variable_pay_eur].present?
        permitted[:variable_pay_cents] = (permitted.delete(:variable_pay_eur).to_f * 100).round
      else
        permitted.delete(:variable_pay_eur)
      end

      permitted
    end
  end
end
