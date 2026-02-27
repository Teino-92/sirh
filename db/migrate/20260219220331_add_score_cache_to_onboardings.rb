class AddScoreCacheToOnboardings < ActiveRecord::Migration[7.1]
  def change
    add_column :onboardings, :progress_percentage_cache, :integer, default: 0, null: false
    add_column :onboardings, :integration_score_cache,   :integer, default: 0, null: false
  end
end
