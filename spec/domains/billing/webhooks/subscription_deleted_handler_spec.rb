# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriptionDeletedHandler, type: :service do
  subject(:handler) { described_class.new }

  # ── Stripe event builder ──────────────────────────────────────────────────
  # Builds a customer.subscription.deleted event.
  def build_event(stripe_sub_id)
    stripe_sub = OpenStruct.new(id: stripe_sub_id)
    data       = OpenStruct.new(object: stripe_sub)
    OpenStruct.new(data: data)
  end

  let(:org) { create(:organization) }

  # ── Cas nominal ───────────────────────────────────────────────────────────
  describe "canceling an active subscription" do
    let!(:sub) do
      create(:subscription, :active, :sirh_essential,
             organization:          org,
             stripe_subscription_id: "sub_del001")
    end

    it "sets status to 'canceled'" do
      handler.call(build_event("sub_del001"))
      expect(sub.reload.status).to eq("canceled")
    end

    it "updates last_webhook_at" do
      freeze_time do
        handler.call(build_event("sub_del001"))
        expect(sub.reload.last_webhook_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe "canceling a past_due subscription" do
    let!(:sub) do
      create(:subscription, :past_due, :sirh_essential,
             organization:          org,
             stripe_subscription_id: "sub_del002")
    end

    it "sets status to 'canceled'" do
      handler.call(build_event("sub_del002"))
      expect(sub.reload.status).to eq("canceled")
    end
  end

  # ── Idempotence ───────────────────────────────────────────────────────────
  describe "idempotence when already canceled" do
    let!(:sub) do
      create(:subscription, :canceled, :sirh_essential,
             organization:          org,
             stripe_subscription_id: "sub_del003",
             last_webhook_at:        2.hours.ago)
    end

    it "skips the update and does not change last_webhook_at" do
      original_webhook_at = sub.last_webhook_at

      freeze_time do
        handler.call(build_event("sub_del003"))
        # last_webhook_at must NOT be updated (early return before update!)
        expect(sub.reload.last_webhook_at).to eq(original_webhook_at)
      end
    end

    it "does not raise" do
      expect { handler.call(build_event("sub_del003")) }.not_to raise_error
    end
  end

  # ── Subscription introuvable ──────────────────────────────────────────────
  describe "when subscription is not found" do
    it "returns early without raising" do
      expect { handler.call(build_event("sub_ghost_xyz")) }.not_to raise_error
    end

    it "does not create or modify any subscriptions" do
      expect { handler.call(build_event("sub_ghost_xyz")) }
        .not_to change(Subscription, :count)
    end
  end
end
