# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.references :organization, null: false, foreign_key: true, index: { unique: true }

      t.string  :stripe_customer_id,      null: false
      t.string  :stripe_subscription_id
      t.string  :plan,                    null: false  # manager_os / sirh_essential / sirh_pro
      t.string  :status,                  null: false, default: "incomplete"
      # trialing / incomplete / active / past_due / canceled / upgrade_pending

      t.datetime :current_period_end
      t.datetime :commitment_end_at       # fin engagement 1 an — résiliation bloquée avant
      t.boolean  :cancel_at_period_end,   null: false, default: false

      t.string  :stripe_checkout_session_id  # pour idempotence checkout
      t.datetime :last_webhook_at

      t.timestamps
    end

    add_index :subscriptions, :stripe_customer_id,      unique: true
    add_index :subscriptions, :stripe_subscription_id,  unique: true, where: "stripe_subscription_id IS NOT NULL"
    add_index :subscriptions, :status
    add_index :subscriptions, :commitment_end_at,        where: "commitment_end_at IS NOT NULL"
  end
end
