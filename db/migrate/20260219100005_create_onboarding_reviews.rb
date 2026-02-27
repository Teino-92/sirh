class CreateOnboardingReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :onboarding_reviews do |t|
      t.bigint :onboarding_id,          null: false
      t.bigint :organization_id,        null: false
      t.string :reviewer_type,          null: false
      t.integer :review_day,            null: false, default: 30
      t.jsonb  :employee_feedback_json, null: false, default: {}
      t.jsonb  :manager_feedback_json,  null: false, default: {}

      t.timestamps
    end

    add_index :onboarding_reviews, [:onboarding_id, :reviewer_type, :review_day],
              unique: true,
              name: 'idx_onboarding_reviews_unique'
    add_index :onboarding_reviews, :organization_id,
              name: 'index_onboarding_reviews_on_organization_id'

    add_foreign_key :onboarding_reviews, :onboardings
    add_foreign_key :onboarding_reviews, :organizations
  end
end
