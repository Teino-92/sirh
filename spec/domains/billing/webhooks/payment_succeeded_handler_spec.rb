# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentSucceededHandler, type: :service do
  subject(:handler) { described_class.new }

  # ── Stripe event builder ──────────────────────────────────────────────────
  # Builds an invoice.payment_succeeded event.
  # Stripe API 2026-02-25: invoice.parent.subscription_details.subscription
  def build_event(stripe_sub_id)
    subscription_details = stripe_sub_id ? OpenStruct.new(subscription: stripe_sub_id) : nil
    parent  = OpenStruct.new(subscription_details: subscription_details)
    invoice = OpenStruct.new(parent: parent)
    data    = OpenStruct.new(object: invoice)
    OpenStruct.new(data: data)
  end

  let(:org) { create(:organization) }

  # ── past_due → active ─────────────────────────────────────────────────────
  describe "reactivation after payment recovery" do
    let!(:sub) do
      create(:subscription, :past_due, :sirh_essential,
             organization:          org,
             stripe_subscription_id: "sub_pay001")
    end

    it "sets status to 'active'" do
      handler.call(build_event("sub_pay001"))
      expect(sub.reload.status).to eq("active")
    end

    it "updates last_webhook_at" do
      freeze_time do
        handler.call(build_event("sub_pay001"))
        expect(sub.reload.last_webhook_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  # ── Already active — only touch ───────────────────────────────────────────
  describe "when subscription is already active" do
    let!(:sub) do
      create(:subscription, :active, :sirh_essential,
             organization:          org,
             stripe_subscription_id: "sub_pay002",
             last_webhook_at:        1.hour.ago)
    end

    it "does not change status" do
      expect {
        handler.call(build_event("sub_pay002"))
      }.not_to change { sub.reload.status }
    end

    it "updates last_webhook_at via touch" do
      freeze_time do
        handler.call(build_event("sub_pay002"))
        expect(sub.reload.last_webhook_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  # ── stripe_sub_id nil (no parent.subscription_details) ───────────────────
  describe "when stripe_sub_id is blank" do
    it "returns early without raising" do
      expect { handler.call(build_event(nil)) }.not_to raise_error
    end

    it "does not modify any subscription" do
      sub = create(:subscription, :past_due,
                   organization:          org,
                   stripe_subscription_id: "sub_pay_untouched")

      handler.call(build_event(nil))
      expect(sub.reload.status).to eq("past_due")
    end
  end

  # ── Subscription introuvable ──────────────────────────────────────────────
  describe "when subscription is not found" do
    it "returns early without raising" do
      expect { handler.call(build_event("sub_ghost_xyz")) }.not_to raise_error
    end
  end
end
