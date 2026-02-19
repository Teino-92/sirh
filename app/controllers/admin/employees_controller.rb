# frozen_string_literal: true

module Admin
  class EmployeesController < BaseController
    before_action :set_employee, only: [:show, :edit, :update, :destroy]

    def index
      @employees = Employee.includes(:organization, :manager, avatar_attachment: :blob)

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
    end

    def new
      @employee = Employee.new
      @employee.organization = current_employee.organization
    end

    def create
      @employee = Employee.new(employee_params)
      @employee.organization = current_employee.organization

      if @employee.save
        # Initialize leave balances
        LeaveManagement::Services::LeaveBalanceInitializer.new(@employee).initialize_balances

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
    end

    def update
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
      @employee = Employee.find(params[:id])
    end

    def employee_params
      params.require(:employee).permit(
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
        :job_title,
        :manager_id,
        :avatar,
        settings: [:cadre]
      )
    end
  end
end
