class CreateOnboardingTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :onboarding_templates do |t|
      t.bigint  :organization_id, null: false
      t.string  :name,            null: false
      t.text    :description
      t.integer :duration_days,   null: false, default: 90
      t.boolean :active,          null: false, default: true

      t.timestamps
    end

    add_index :onboarding_templates, [:organization_id, :active],
              name: 'idx_onboarding_templates_org_active'
    add_index :onboarding_templates, :organization_id,
              name: 'index_onboarding_templates_on_organization_id'

    add_foreign_key :onboarding_templates, :organizations
  end
end
