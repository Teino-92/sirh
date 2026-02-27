# frozen_string_literal: true

module Admin
  class GroupPoliciesController < BaseController
    def edit
      @organization = current_employee.organization
      authorize @organization, policy_class: GroupPoliciesPolicy
      @policies = @organization.group_policies
    end

    def preview
      @organization = current_employee.organization
      authorize @organization, policy_class: GroupPoliciesPolicy
      @policies = policy_params.to_h
      @affected = compute_affected
      render turbo_stream: turbo_stream.replace(
        'policy-preview',
        partial: 'admin/group_policies/preview',
        locals: { affected: @affected, policies: @policies }
      )
    end

    def update
      org = current_employee.organization
      authorize org, policy_class: GroupPoliciesPolicy
      merged = org.settings.merge('group_policies' => normalize_policy_params)
      org.update!(settings: merged)
      redirect_to edit_admin_group_policies_path, notice: 'Règles RH mises à jour.'
    end

    private

    def policy_params
      params.require(:group_policies).permit(
        :manager_can_approve_leave,
        auto_approve_leave_by_role: Employee::ROLES
      )
    end

    # Normalize checkbox strings ("1"/"0"/nil) to booleans before storing in JSONB
    def normalize_policy_params
      cast = ActiveRecord::Type::Boolean.new
      raw = policy_params.to_h

      auto_by_role = (raw['auto_approve_leave_by_role'] || {}).transform_values { |v| cast.cast(v) == true }

      {
        'manager_can_approve_leave' => cast.cast(raw['manager_can_approve_leave']) == true,
        'auto_approve_leave_by_role' => auto_by_role
      }
    end

    def compute_affected
      org = current_employee.organization
      {
        managers: org.employees.where(role: 'manager').count,
        by_role: org.employees.group(:role).count
      }
    end
  end
end
