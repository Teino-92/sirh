# frozen_string_literal: true

class RenameOnboardingsToEmployeeOnboardings < ActiveRecord::Migration[7.1]
  def change
    rename_table :onboardings, :employee_onboardings

    # onboarding_tasks.onboarding_id → employee_onboarding_id
    rename_column :onboarding_tasks,   :onboarding_id, :employee_onboarding_id
    # onboarding_reviews.onboarding_id → employee_onboarding_id
    rename_column :onboarding_reviews, :onboarding_id, :employee_onboarding_id
  end
end
