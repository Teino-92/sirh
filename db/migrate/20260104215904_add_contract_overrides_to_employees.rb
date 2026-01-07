class AddContractOverridesToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :contract_overrides, :jsonb, default: {}, null: false
  end
end
