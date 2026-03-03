# frozen_string_literal: true

class AddEventIndexToVersions < ActiveRecord::Migration[7.1]
  def change
    add_index :versions, %i[item_type item_id event],
              name: 'index_versions_on_item_type_item_id_event'
  end
end
