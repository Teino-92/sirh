# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriptionUpdatedHandler, type: :service do
  subject(:handler) { described_class.new }

  def build_event(stripe_sub_id:, status:, period_end: 30.days.from_now.to_i,
                  cancel_at_period_end: false, price_id: nil, lookup_key: nil,
                  org_id: nil)
    price = if price_id || lookup_key
              OpenStruct.new(id: price_id, lookup_key: lookup_key)
            end
    item  = OpenStruct.new(price: price)
    items = OpenStruct.new(data: price ? [item] : [])

    # Simule Stripe::StripeObject metadata — respond à metadata["organization_id"]
    meta_hash = org_id ? { "organization_id" => org_id.to_s } : {}
    meta = meta_hash

    stripe_sub = OpenStruct.new(
      id:                   stripe_sub_id,
      status:               status,
      current_period_end:   period_end,
      cancel_at_period_end: cancel_at_period_end,
      items:                items,
      metadata:             meta
    )
    data = OpenStruct.new(object: stripe_sub)
    OpenStruct.new(data: data)
  end

  let(:org) { create(:organization) }
  let!(:sub) do
    create(:subscription, :active, :sirh_essential,
           organization:           org,
           stripe_subscription_id: "sub_update001")
  end

  # ── Attribute updates ─────────────────────────────────────────────────────
  describe "attribute updates" do
    it "updates status" do
      event = build_event(stripe_sub_id: "sub_update001", status: "past_due")
      handler.call(event)
      expect(sub.reload.status).to eq("past_due")
    end

    it "updates current_period_end" do
      future = 45.days.from_now
      event  = build_event(stripe_sub_id: "sub_update001", status: "active",
                           period_end: future.to_i)
      freeze_time do
        handler.call(event)
        expect(sub.reload.current_period_end).to be_within(1.second).of(future)
      end
    end

    it "updates cancel_at_period_end to true" do
      event = build_event(stripe_sub_id: "sub_update001", status: "active",
                          cancel_at_period_end: true)
      handler.call(event)
      expect(sub.reload.cancel_at_period_end).to be true
    end

    it "updates last_webhook_at" do
      freeze_time do
        event = build_event(stripe_sub_id: "sub_update001", status: "active")
        handler.call(event)
        expect(sub.reload.last_webhook_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  # ── Status mapping ────────────────────────────────────────────────────────
  describe "Stripe → internal status mapping" do
    {
      "active"             => "active",
      "trialing"           => "trialing",
      "past_due"           => "past_due",
      "canceled"           => "canceled",
      "incomplete"         => "incomplete",
      "incomplete_expired" => "canceled"
    }.each do |stripe_status, expected|
      it "maps Stripe status '#{stripe_status}' to internal '#{expected}'" do
        event = build_event(stripe_sub_id: "sub_update001", status: stripe_status)
        handler.call(event)
        expect(sub.reload.status).to eq(expected)
      end
    end

    it "defaults unknown Stripe status to 'active'" do
      event = build_event(stripe_sub_id: "sub_update001", status: "unknown_future_status")
      handler.call(event)
      expect(sub.reload.status).to eq("active")
    end
  end

  # ── Plan resolution via lookup_key ────────────────────────────────────────
  describe "plan update via lookup_key" do
    it "updates plan to 'sirh_pro' when lookup_key is 'sirh_pro_monthly'" do
      event = build_event(stripe_sub_id: "sub_update001", status: "active",
                          lookup_key: "sirh_pro_monthly")
      handler.call(event)
      expect(sub.reload.plan).to eq("sirh_pro")
    end

    it "updates plan to 'manager_os' when lookup_key is 'managerOS_monthly'" do
      event = build_event(stripe_sub_id: "sub_update001", status: "active",
                          lookup_key: "managerOS_monthly")
      handler.call(event)
      expect(sub.reload.plan).to eq("manager_os")
    end

    it "updates plan to 'sirh_essential' when lookup_key is 'sirh_essentiel_monthly'" do
      sub.update_columns(plan: "sirh_pro")
      event = build_event(stripe_sub_id: "sub_update001", status: "active",
                          lookup_key: "sirh_essentiel_monthly")
      handler.call(event)
      expect(sub.reload.plan).to eq("sirh_essential")
    end

    it "does not change plan when lookup_key matches the current plan" do
      expect {
        event = build_event(stripe_sub_id: "sub_update001", status: "active",
                            lookup_key: "sirh_essentiel_monthly")
        handler.call(event)
      }.not_to change { sub.reload.plan }
    end
  end

  # ── Plan resolution via env var ───────────────────────────────────────────
  describe "plan update via env var price ID match" do
    it "resolves plan from STRIPE_PRICE_SIRH_PRO env var" do
      ClimateControl.modify(STRIPE_PRICE_SIRH_PRO: "price_pro_from_env") do
        event = build_event(stripe_sub_id: "sub_update001", status: "active",
                            price_id: "price_pro_from_env")
        handler.call(event)
        expect(sub.reload.plan).to eq("sirh_pro")
      end
    end
  end if defined?(ClimateControl)

  # ── No plan change when no price info ────────────────────────────────────
  describe "plan update when no price data" do
    it "does not change the plan" do
      event = build_event(stripe_sub_id: "sub_update001", status: "active",
                          price_id: nil, lookup_key: nil)
      expect {
        handler.call(event)
      }.not_to change { sub.reload.plan }
    end
  end

  # ── Subscription introuvable ──────────────────────────────────────────────
  describe "when subscription is not found" do
    it "returns early without raising" do
      event = build_event(stripe_sub_id: "sub_unknown_xyz", status: "active")
      expect { handler.call(event) }.not_to raise_error
    end

    it "does not modify any existing subscription" do
      event = build_event(stripe_sub_id: "sub_unknown_xyz", status: "past_due")
      expect {
        handler.call(event)
      }.not_to change { sub.reload.status }
    end
  end

  # ── Cross-tenant guard ────────────────────────────────────────────────────
  describe "cross-tenant guard" do
    let(:other_org) { create(:organization) }

    it "does not update subscription when stripe org_id mismatches" do
      # Stripe metadata points to other_org, but the sub belongs to org
      event = build_event(
        stripe_sub_id: "sub_update001",
        status:        "active",
        org_id:        other_org.id
      )
      expect {
        handler.call(event)
      }.not_to change { sub.reload.status }
    end

    it "updates normally when stripe org_id matches the sub's org" do
      event = build_event(
        stripe_sub_id: "sub_update001",
        status:        "past_due",
        org_id:        org.id
      )
      handler.call(event)
      expect(sub.reload.status).to eq("past_due")
    end

    it "updates normally when stripe metadata has no org_id (legacy webhooks)" do
      event = build_event(
        stripe_sub_id: "sub_update001",
        status:        "past_due",
        org_id:        nil
      )
      handler.call(event)
      expect(sub.reload.status).to eq("past_due")
    end
  end
end
