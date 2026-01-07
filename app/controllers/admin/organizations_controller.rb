# frozen_string_literal: true

module Admin
  class OrganizationsController < BaseController
    before_action :set_organization

    def show
    end

    def edit
    end

    def update
      if @organization.update(organization_params)
        respond_to do |format|
          format.html { redirect_to admin_organization_path, notice: 'Paramètres de l\'organisation mis à jour avec succès.' }
          format.turbo_stream
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream
        end
      end
    end

    private

    def set_organization
      @organization = current_employee.organization
    end

    def organization_params
      params.require(:organization).permit(
        :name,
        :address,
        :siret,
        settings: [
          :work_week_hours,
          :cp_acquisition_rate,
          :cp_expiry_month,
          :cp_expiry_day,
          :rtt_enabled,
          :overtime_threshold,
          :max_daily_hours,
          :min_consecutive_leave_days
        ]
      )
    end
  end
end
