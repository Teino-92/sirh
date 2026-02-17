class CreateTrainings < ActiveRecord::Migration[7.1]
  def change
    create_table :trainings do |t|
      t.references :organization, null: false, foreign_key: true, index: true

      t.string :title, null: false, limit: 255
      t.text :description
      t.string :training_type, null: false, index: true
      t.integer :duration_estimate  # Minutes
      t.string :provider
      t.string :external_url
      t.datetime :archived_at, index: true

      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :trainings, [:organization_id, :training_type], name: 'idx_trainings_org_type'
  end
end
