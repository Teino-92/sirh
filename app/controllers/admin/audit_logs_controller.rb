# frozen_string_literal: true

module Admin
  class AuditLogsController < Admin::BaseController
    AUDITED_TYPES = %w[LeaveBalance LeaveRequest EmployeeOnboarding].freeze
    PER_PAGE = 50

    def show
      authorize :audit_log, :show?

      scope = PaperTrail::Version.where(organization_id: current_organization.id)
                                 .where(item_type: AUDITED_TYPES)

      scope = scope.where(item_type: params[:item_type]) if params[:item_type].present?
      scope = scope.where(event: params[:event])         if params[:event].present?
      scope = scope.where(whodunnit: params[:whodunnit]) if params[:whodunnit].present?

      if params[:from].present?
        scope = scope.where('created_at >= ?', params[:from].to_date.beginning_of_day)
      end
      if params[:to].present?
        scope = scope.where('created_at <= ?', params[:to].to_date.end_of_day)
      end

      @versions = scope.order(created_at: :desc).page(params[:page]).per(PER_PAGE)
      @item_types = AUDITED_TYPES
    end
  end
end
