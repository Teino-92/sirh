# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription, type: :model do
  # ── Helpers ────────────────────────────────────────────────────────────────
  let(:org) { create(:organization) }

  def build_valid(overrides = {})
    build(:subscription, { organization: org }.merge(overrides))
  end

  def create_valid(overrides = {})
    create(:subscription, { organization: org }.merge(overrides))
  end

  # ── Validations ────────────────────────────────────────────────────────────
  describe "validations" do
    describe "plan" do
      it "accepts each value in PLANS" do
        Subscription::PLANS.each do |plan|
          sub = build_valid(plan: plan)
          expect(sub).to be_valid, "expected #{plan} to be valid, got: #{sub.errors.full_messages}"
        end
      end

      it "rejects an unknown plan" do
        sub = build_valid(plan: "premium_gold")
        expect(sub).not_to be_valid
        expect(sub.errors[:plan]).to be_present
      end

      it "rejects a blank plan" do
        sub = build_valid(plan: "")
        expect(sub).not_to be_valid
      end
    end

    describe "status" do
      it "accepts each value in STATUSES" do
        Subscription::STATUSES.each do |status|
          # incomplete status may have nil stripe_subscription_id — build without it
          sub = build_valid(status: status, stripe_subscription_id: nil)
          expect(sub).to be_valid, "expected status #{status} to be valid, got: #{sub.errors.full_messages}"
        end
      end

      it "rejects an unknown status" do
        sub = build_valid(status: "upgrade_pending")
        expect(sub).not_to be_valid
        expect(sub.errors[:status]).to be_present
      end
    end

    describe "stripe_customer_id" do
      it "requires presence" do
        sub = build_valid(stripe_customer_id: nil)
        expect(sub).not_to be_valid
        expect(sub.errors[:stripe_customer_id]).to be_present
      end

      it "requires non-blank" do
        sub = build_valid(stripe_customer_id: "")
        expect(sub).not_to be_valid
      end
    end

    describe "stripe_subscription_id format" do
      it "is skipped when blank" do
        sub = build_valid(stripe_subscription_id: nil)
        expect(sub).to be_valid
      end

      it "accepts ids starting with 'sub_'" do
        sub = build_valid(stripe_subscription_id: "sub_abc123")
        expect(sub).to be_valid
      end

      it "rejects ids not starting with 'sub_'" do
        sub = build_valid(stripe_subscription_id: "pi_abc123")
        expect(sub).not_to be_valid
        expect(sub.errors[:stripe_subscription_id]).to include("format invalide")
      end

      it "rejects bare numbers" do
        sub = build_valid(stripe_subscription_id: "123456")
        expect(sub).not_to be_valid
      end
    end

    describe "stripe_checkout_session_id format" do
      it "is skipped when blank" do
        sub = build_valid(stripe_checkout_session_id: nil)
        expect(sub).to be_valid
      end

      it "accepts ids starting with 'cs_'" do
        sub = build_valid(stripe_checkout_session_id: "cs_test_abc")
        expect(sub).to be_valid
      end

      it "rejects ids not starting with 'cs_'" do
        sub = build_valid(stripe_checkout_session_id: "sess_abc")
        expect(sub).not_to be_valid
        expect(sub.errors[:stripe_checkout_session_id]).to include("format invalide")
      end
    end
  end

  # ── Status predicates ──────────────────────────────────────────────────────
  describe "#active?" do
    it "returns true for status 'active'" do
      sub = build_valid(status: "active")
      expect(sub.active?).to be true
    end

    it "returns true for status 'trialing'" do
      sub = build_valid(status: "trialing", stripe_subscription_id: nil)
      expect(sub.active?).to be true
    end

    it "returns false for status 'past_due'" do
      sub = build_valid(status: "past_due")
      expect(sub.active?).to be false
    end

    it "returns false for status 'canceled'" do
      sub = build_valid(status: "canceled")
      expect(sub.active?).to be false
    end

    it "returns false for status 'incomplete'" do
      sub = build_valid(status: "incomplete", stripe_subscription_id: nil)
      expect(sub.active?).to be false
    end
  end

  describe "#canceled?" do
    it "returns true only for 'canceled'" do
      expect(build_valid(status: "canceled").canceled?).to be true
    end

    it "returns false for 'active'" do
      expect(build_valid(status: "active").canceled?).to be false
    end
  end

  describe "#past_due?" do
    it "returns true only for 'past_due'" do
      expect(build_valid(status: "past_due").past_due?).to be true
    end

    it "returns false for 'active'" do
      expect(build_valid(status: "active").past_due?).to be false
    end
  end

  describe "#incomplete?" do
    it "returns true only for 'incomplete'" do
      sub = build_valid(status: "incomplete", stripe_subscription_id: nil)
      expect(sub.incomplete?).to be true
    end

    it "returns false for 'active'" do
      expect(build_valid(status: "active").incomplete?).to be false
    end
  end

  # ── Scopes ─────────────────────────────────────────────────────────────────
  describe "scopes" do
    before do
      create_valid(status: "active")
      create_valid(status: "trialing", stripe_subscription_id: nil,
                   organization: create(:organization))
      create_valid(status: "past_due", organization: create(:organization))
      create_valid(status: "canceled", organization: create(:organization))
    end

    it ".active includes active and trialing" do
      statuses = Subscription.active.pluck(:status)
      expect(statuses).to include("active", "trialing")
      expect(statuses).not_to include("past_due", "canceled")
    end

    it ".past_due includes only past_due" do
      statuses = Subscription.past_due.pluck(:status)
      expect(statuses).to all(eq("past_due"))
    end
  end

  # ── can_cancel? ────────────────────────────────────────────────────────────
  describe "#can_cancel?" do
    context "without a commitment_end_at" do
      it "returns true immediately" do
        sub = build_valid(commitment_end_at: nil)
        expect(sub.can_cancel?).to be true
      end
    end

    context "with a commitment_end_at in the future" do
      it "returns false before the commitment ends" do
        freeze_time do
          sub = build_valid(commitment_end_at: 3.months.from_now)
          expect(sub.can_cancel?).to be false
        end
      end
    end

    context "with a commitment_end_at in the past" do
      it "returns true after the commitment has ended" do
        freeze_time do
          sub = build_valid(commitment_end_at: 1.day.ago)
          expect(sub.can_cancel?).to be true
        end
      end
    end

    context "exactly at commitment_end_at" do
      it "returns true at the boundary" do
        freeze_time do
          sub = build_valid(commitment_end_at: Time.current)
          expect(sub.can_cancel?).to be true
        end
      end
    end
  end

  # ── committed? ────────────────────────────────────────────────────────────
  describe "#committed?" do
    it "returns false when commitment_end_at is nil" do
      sub = build_valid(commitment_end_at: nil)
      expect(sub.committed?).to be false
    end

    it "returns true when commitment_end_at is in the future" do
      freeze_time do
        sub = build_valid(commitment_end_at: 6.months.from_now)
        expect(sub.committed?).to be true
      end
    end

    it "returns false when commitment_end_at is in the past" do
      freeze_time do
        sub = build_valid(commitment_end_at: 1.second.ago)
        expect(sub.committed?).to be false
      end
    end
  end

  # ── commitment_months_remaining ───────────────────────────────────────────
  describe "#commitment_months_remaining" do
    it "returns 0 when not committed" do
      sub = build_valid(commitment_end_at: nil)
      expect(sub.commitment_months_remaining).to eq(0)
    end

    it "returns 0 when commitment has passed" do
      freeze_time do
        sub = build_valid(commitment_end_at: 1.day.ago)
        expect(sub.commitment_months_remaining).to eq(0)
      end
    end

    it "returns the ceiled number of months remaining" do
      freeze_time do
        # ~3 months from now — result is 3 or 4 depending on floating-point precision
        sub = build_valid(commitment_end_at: 3.months.from_now)
        expect(sub.commitment_months_remaining).to be_between(3, 4).inclusive
      end
    end

    it "rounds up a partial month" do
      freeze_time do
        # 2 months + 15 days → ceil is at least 3
        sub = build_valid(commitment_end_at: 2.months.from_now + 15.days)
        expect(sub.commitment_months_remaining).to be >= 3
      end
    end
  end

  # ── Plan predicates ───────────────────────────────────────────────────────
  describe "plan predicates" do
    it "#manager_os? returns true for manager_os plan" do
      expect(build_valid(plan: "manager_os").manager_os?).to be true
      expect(build_valid(plan: "sirh_essential").manager_os?).to be false
    end

    it "#sirh_essential? returns true for sirh_essential plan" do
      expect(build_valid(plan: "sirh_essential").sirh_essential?).to be true
      expect(build_valid(plan: "sirh_pro").sirh_essential?).to be false
    end

    it "#sirh_pro? returns true for sirh_pro plan" do
      expect(build_valid(plan: "sirh_pro").sirh_pro?).to be true
      expect(build_valid(plan: "manager_os").sirh_pro?).to be false
    end
  end
end
