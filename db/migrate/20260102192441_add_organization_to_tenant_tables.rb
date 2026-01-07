class AddOrganizationToTenantTables < ActiveRecord::Migration[7.1]
  def change
    # Tables à scoper par organisation
    tables = [
      :time_entries,
      :leave_requests,
      :leave_balances,
      :work_schedules,
      :weekly_schedule_plans,
      :notifications
    ]

    tables.each do |table|
      # Ajouter la colonne organization_id (nullable pour le moment)
      add_reference table, :organization, foreign_key: true, index: false

      # Index composite pour performance des requêtes scopées
      add_index table, [:organization_id, :created_at]
    end
  end
end
