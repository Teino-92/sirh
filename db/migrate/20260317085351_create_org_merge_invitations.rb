# frozen_string_literal: true

class CreateOrgMergeInvitations < ActiveRecord::Migration[7.1]
  def change
    create_table :org_merge_invitations do |t|
      t.bigint  :target_organization_id, null: false
      t.bigint  :source_organization_id, null: false
      t.string  :invited_email, null: false
      t.string  :token, null: false
      t.string  :status, default: 'pending', null: false
      t.bigint  :invited_by_id, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :completed_at
      t.jsonb   :merge_log, default: {}, null: false
      t.timestamps
    end

    add_index :org_merge_invitations, :token, unique: true
    add_index :org_merge_invitations, [:target_organization_id, :status]
    add_index :org_merge_invitations, :source_organization_id
    add_index :org_merge_invitations, [:source_organization_id, :status],
              unique: true,
              where: "status IN ('pending', 'accepted', 'merging')",
              name: 'idx_org_merge_invitations_source_active_unique'
  end
end
