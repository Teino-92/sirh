class AddJobTitleAndDepartmentToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :job_title, :string unless column_exists?(:employees, :job_title)
  end
end
