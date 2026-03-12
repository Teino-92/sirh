# frozen_string_literal: true

class AddTrialEndsAtToOrganizations < ActiveRecord::Migration[7.1]
  def change
    add_column :organizations, :trial_ends_at, :datetime

    add_index :organizations, :trial_ends_at,
              name: "index_organizations_on_trial_ends_at",
              where: "trial_ends_at IS NOT NULL"
  end
end
