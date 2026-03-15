# frozen_string_literal: true

module SuperAdmin
  class AnalyticsController < BaseController
    def show
      # KPIs globaux
      @total_orgs        = Organization.count
      @total_employees   = Employee.unscoped.count

      # Trials
      now = Time.current
      @trials_active     = Organization.where('trial_ends_at >= ?', now).count
      @trials_expired    = Organization.where('trial_ends_at < ?', now).count
      @trials_converted  = Subscription.where(status: 'active').count

      # Répartition par plan
      @by_plan = Organization.group(:plan).count

      # Nouvelles orgs par jour sur 30 jours
      @signups_by_day = Organization
        .where('created_at >= ?', 30.days.ago)
        .group("DATE(created_at)")
        .order("DATE(created_at)")
        .count

      # Tableau de toutes les orgs
      @organizations = Organization
        .includes(:subscription)
        .order(created_at: :desc)
    end
  end
end
