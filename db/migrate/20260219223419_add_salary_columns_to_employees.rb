class AddSalaryColumnsToEmployees < ActiveRecord::Migration[7.1]
  def change
    # Salaries stored in cents (integer) to avoid floating-point errors.
    # gross_salary_cents: monthly gross salary before charges (e.g. 3500_00 = 3 500 €/mois)
    # variable_pay_cents: monthly variable component (primes, commissions)
    # employer_charges_rate: multiplicative coefficient for employer charges (e.g. 1.45 means +45%)
    add_column :employees, :gross_salary_cents,    :integer, default: 0, null: false
    add_column :employees, :variable_pay_cents,    :integer, default: 0, null: false
    add_column :employees, :employer_charges_rate, :decimal, precision: 5, scale: 4, default: '1.45', null: false
  end
end
