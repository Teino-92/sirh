# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckoutCompletedHandler, type: :service do
  subject(:handler) { described_class.new }

  # ── Stripe event builder ───────────────────────────────────────────────────
  # Builds a minimal checkout.session.completed event structure
  # mirroring Stripe API 2026-02-25: event.data.object = Checkout::Session
  def build_event(org_id:, plan:, session_id: "cs_test_abc123",
                  customer: "cus_test001", subscription: "sub_test001",
                  mode: "subscription")
    session = OpenStruct.new(
      mode:         mode,
      id:           session_id,
      customer:     customer,
      subscription: subscription,
      metadata:     { "organization_id" => org_id.to_s, "plan" => plan }
    )
    data  = OpenStruct.new(object: session)
    OpenStruct.new(data: data)
  end

  # ── Cas nominal ──────────────────────────────────────────────────────────
  describe "successful checkout" do
    let(:org) { create(:organization, plan: "manager_os") }

    it "creates a Subscription record with status active" do
      expect {
        freeze_time { handler.call(build_event(org_id: org.id, plan: "sirh_essential")) }
      }.to change(Subscription, :count).by(1)

      sub = Subscription.find_by(organization_id: org.id)
      expect(sub.status).to eq("active")
      expect(sub.plan).to  eq("sirh_essential")
    end

    it "sets stripe identifiers on the subscription" do
      freeze_time do
        handler.call(build_event(
          org_id:       org.id,
          plan:         "sirh_essential",
          session_id:   "cs_test_session",
          customer:     "cus_customer01",
          subscription: "sub_subscription01"
        ))
      end

      sub = Subscription.find_by(organization_id: org.id)
      expect(sub.stripe_checkout_session_id).to eq("cs_test_session")
      expect(sub.stripe_customer_id).to         eq("cus_customer01")
      expect(sub.stripe_subscription_id).to     eq("sub_subscription01")
    end

    it "sets commitment_end_at to 12 months from now" do
      freeze_time do
        handler.call(build_event(org_id: org.id, plan: "sirh_essential"))
        sub = Subscription.find_by(organization_id: org.id)
        expect(sub.commitment_end_at).to be_within(1.second).of(12.months.from_now)
      end
    end

    it "updates org.plan to 'sirh' for a sirh plan" do
      freeze_time { handler.call(build_event(org_id: org.id, plan: "sirh_essential")) }
      expect(org.reload.plan).to eq("sirh")
    end

    it "updates org.plan to 'sirh' for sirh_pro as well" do
      freeze_time { handler.call(build_event(org_id: org.id, plan: "sirh_pro")) }
      expect(org.reload.plan).to eq("sirh")
    end

    it "keeps org.plan as 'manager_os' for a manager_os plan" do
      freeze_time { handler.call(build_event(org_id: org.id, plan: "manager_os")) }
      expect(org.reload.plan).to eq("manager_os")
    end

    it "updates an existing incomplete subscription instead of creating a new one" do
      existing = create(:subscription, :incomplete,
                        organization: org,
                        stripe_customer_id: "cus_customer01")

      expect {
        freeze_time { handler.call(build_event(org_id: org.id, plan: "sirh_essential")) }
      }.not_to change(Subscription, :count)

      expect(existing.reload.status).to eq("active")
    end
  end

  # ── Idempotence ───────────────────────────────────────────────────────────
  describe "idempotence" do
    let(:org) { create(:organization) }
    let(:session_id) { "cs_test_idempotent" }

    it "skips processing when the same session_id is already active" do
      create(:subscription,
             organization:               org,
             stripe_checkout_session_id: session_id,
             stripe_customer_id:         "cus_xxx",
             stripe_subscription_id:     "sub_xxx",
             status:                     "active",
             plan:                       "sirh_essential")

      event = build_event(org_id: org.id, plan: "sirh_pro", session_id: session_id)

      expect {
        handler.call(event)
      }.not_to change { Subscription.find_by(organization_id: org.id).plan }
    end

    it "does not raise when called twice with the same event" do
      event = build_event(org_id: org.id, plan: "sirh_essential", session_id: session_id)

      freeze_time do
        expect { handler.call(event) }.not_to raise_error
        expect { handler.call(event) }.not_to raise_error
      end
    end
  end

  # ── Organisation introuvable ───────────────────────────────────────────────
  describe "when organization is not found" do
    it "returns early without raising or persisting data" do
      event = build_event(org_id: 99999999, plan: "sirh_essential")

      expect { handler.call(event) }.not_to raise_error
      expect(Subscription.count).to eq(0)
    end
  end

  # ── Mode != subscription ──────────────────────────────────────────────────
  describe "when checkout mode is not 'subscription'" do
    let(:org) { create(:organization) }

    it "returns early and does not create a subscription" do
      event = build_event(org_id: org.id, plan: "sirh_essential", mode: "payment")

      expect {
        handler.call(event)
      }.not_to change(Subscription, :count)
    end
  end
end
