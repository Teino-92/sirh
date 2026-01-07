class AddProfileFieldsToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :phone, :string
    add_column :employees, :address, :text
  end
end
