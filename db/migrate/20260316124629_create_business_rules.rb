class CreateBusinessRules < ActiveRecord::Migration[7.1]
  def change
    create_table :business_rules do |t|
      t.references :organization, null: false, foreign_key: true
      t.string  :name,        null: false
      t.string  :trigger,     null: false  # e.g. "leave_request.submitted"
      t.jsonb   :conditions,  null: false, default: []
      t.jsonb   :actions,     null: false, default: []
      t.integer :priority,    null: false, default: 0
      t.boolean :active,      null: false, default: true
      t.text    :description

      t.timestamps
    end

    add_index :business_rules, [ :organization_id, :trigger, :active ],
              name: 'idx_business_rules_org_trigger_active'
    add_index :business_rules, [ :organization_id, :priority ]
  end
end
