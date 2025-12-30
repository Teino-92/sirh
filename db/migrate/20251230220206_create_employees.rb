class CreateEmployees < ActiveRecord::Migration[7.1]
  def change
    create_table :employees do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :email, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :role, null: false, default: 'employee'
      t.string :department
      t.string :contract_type, null: false
      t.date :start_date, null: false
      t.bigint :manager_id
      t.jsonb :settings, default: {}, null: false

      t.timestamps
    end

    add_index :employees, :email, unique: true
    add_index :employees, [:organization_id, :email], unique: true
    add_index :employees, :manager_id
    add_index :employees, :role
    add_index :employees, :department
    add_foreign_key :employees, :employees, column: :manager_id
  end
end
