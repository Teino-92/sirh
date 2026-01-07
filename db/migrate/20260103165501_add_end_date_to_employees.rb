class AddEndDateToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :end_date, :date
  end
end
