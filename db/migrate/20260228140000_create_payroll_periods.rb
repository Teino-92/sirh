# frozen_string_literal: true

class CreatePayrollPeriods < ActiveRecord::Migration[7.1]
  def change
    create_table :payroll_periods do |t|
      t.bigint   :organization_id, null: false
      t.date     :period,          null: false  # always beginning_of_month
      t.datetime :locked_at,       null: false
      t.bigint   :locked_by_id,    null: false
      t.text     :notes

      t.timestamps
    end

    add_index :payroll_periods, [:organization_id, :period], unique: true
    add_foreign_key :payroll_periods, :organizations
    add_foreign_key :payroll_periods, :employees, column: :locked_by_id
  end
end
