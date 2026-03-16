# frozen_string_literal: true

class CreateEmployeeDelegations < ActiveRecord::Migration[7.1]
  def change
    create_table :employee_delegations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :delegator,    null: false, foreign_key: { to_table: :employees }
      t.references :delegatee,    null: false, foreign_key: { to_table: :employees }
      t.string     :role,         null: false
      t.datetime   :starts_at,    null: false
      t.datetime   :ends_at,      null: false
      t.text       :reason
      t.boolean    :active,       null: false, default: true
      t.timestamps
    end

    add_index :employee_delegations,
              [:organization_id, :delegatee_id, :starts_at, :ends_at],
              name: 'idx_delegations_org_delegatee_dates'

    add_index :employee_delegations,
              [:organization_id, :active, :ends_at],
              name: 'idx_delegations_org_active_ends_at'
  end
end
