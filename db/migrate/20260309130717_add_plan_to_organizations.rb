class AddPlanToOrganizations < ActiveRecord::Migration[7.1]
  def change
    add_column :organizations, :plan, :string, null: false, default: "sirh"
    add_column :organizations, :plan_started_at, :datetime
    add_column :organizations, :billing_model, :string, null: false, default: "per_employee"

    add_index :organizations, :plan
  end
end
