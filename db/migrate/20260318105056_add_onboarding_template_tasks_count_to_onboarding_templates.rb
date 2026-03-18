class AddOnboardingTemplateTasksCountToOnboardingTemplates < ActiveRecord::Migration[7.1]
  def change
    add_column :onboarding_templates, :onboarding_template_tasks_count, :integer, default: 0, null: false

    # Backfill existing records
    OnboardingTemplate.find_each do |t|
      OnboardingTemplate.reset_counters(t.id, :onboarding_template_tasks)
    end
  end
end
