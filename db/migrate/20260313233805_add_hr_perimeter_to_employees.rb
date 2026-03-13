class AddHrPerimeterToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :hr_perimeter, :text, array: true, default: []
    add_index :employees, :hr_perimeter, using: :gin
  end
end
