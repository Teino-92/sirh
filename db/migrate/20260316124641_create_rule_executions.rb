class CreateRuleExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :rule_executions do |t|
      t.references :organization,   null: false, foreign_key: true
      t.references :business_rule,  null: false, foreign_key: true
      t.string  :trigger,           null: false
      t.string  :resource_type,     null: false  # e.g. "LeaveRequest"
      t.integer :resource_id,       null: false
      t.jsonb   :context,           null: false, default: {}
      t.jsonb   :actions_executed,  null: false, default: []
      t.string  :result,            null: false, default: 'executed'  # executed | skipped | failed
      t.text    :error_message

      t.timestamps
    end

    add_index :rule_executions, [ :organization_id, :created_at ]
    add_index :rule_executions, [ :resource_type, :resource_id ]
  end
end
