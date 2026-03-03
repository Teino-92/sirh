# frozen_string_literal: true

class AddPayrollFieldsToEmployees < ActiveRecord::Migration[7.1]
  def change
    add_column :employees, :nir,                  :string, limit: 255  # stored encrypted
    add_column :employees, :nir_key,               :string, limit: 2
    add_column :employees, :birth_date,            :date
    add_column :employees, :birth_city,            :string
    add_column :employees, :birth_department,      :string, limit: 3
    add_column :employees, :birth_country,         :string, default: 'FR'
    add_column :employees, :nationality,           :string, default: 'FR'
    add_column :employees, :iban,                  :string, limit: 255  # stored encrypted
    add_column :employees, :bic,                   :string
    add_column :employees, :convention_collective, :string
    add_column :employees, :qualification,         :string
    add_column :employees, :coefficient,           :string
    add_column :employees, :part_time_rate,        :decimal, precision: 5, scale: 4, default: '1.0'
    add_column :employees, :trial_period_end,      :date
    add_column :employees, :termination_date,      :date
    add_column :employees, :termination_reason,    :string

    add_index :employees, :birth_date
  end
end
