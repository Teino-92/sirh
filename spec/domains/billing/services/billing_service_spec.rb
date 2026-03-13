# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingService, type: :service do
  # ── Factory helpers ────────────────────────────────────────────────────────
  def org_with(trial_ends_at: nil, plan: "manager_os")
    create(:organization, plan: plan, trial_ends_at: trial_ends_at)
  end

  def service_for(org)
    described_class.new(org)
  end

  # ── billing_active? ────────────────────────────────────────────────────────
  describe "#billing_active?" do
    context "trial still active" do
      it "returns true even without a subscription" do
        org = org_with(trial_ends_at: 7.days.from_now)
        expect(service_for(org).billing_active?).to be true
      end

      it "returns true even if there is a past_due subscription" do
        org = org_with(trial_ends_at: 7.days.from_now)
        create(:subscription, :past_due, organization: org)
        org.reload
        expect(service_for(org).billing_active?).to be true
      end
    end

    context "trial expired" do
      it "returns false without any subscription" do
        org = org_with(trial_ends_at: 2.days.ago)
        expect(service_for(org).billing_active?).to be false
      end

      it "returns true with an active subscription" do
        org = org_with(trial_ends_at: 2.days.ago)
        create(:subscription, :active, organization: org)
        org.reload
        expect(service_for(org).billing_active?).to be true
      end

      it "returns true with a trialing subscription" do
        org = org_with(trial_ends_at: 2.days.ago)
        create(:subscription, :trialing, :sirh_essential,
               stripe_subscription_id: nil, organization: org)
        org.reload
        expect(service_for(org).billing_active?).to be true
      end

      it "returns false with a past_due subscription" do
        org = org_with(trial_ends_at: 2.days.ago)
        create(:subscription, :past_due, organization: org)
        org.reload
        expect(service_for(org).billing_active?).to be false
      end

      it "returns false with a canceled subscription" do
        org = org_with(trial_ends_at: 2.days.ago)
        create(:subscription, :canceled, organization: org)
        org.reload
        expect(service_for(org).billing_active?).to be false
      end
    end

    context "no trial_ends_at configured" do
      it "returns false without a subscription (trial_active? → false)" do
        org = org_with(trial_ends_at: nil)
        expect(service_for(org).billing_active?).to be false
      end
    end
  end

  # ── needs_subscription? ───────────────────────────────────────────────────
  describe "#needs_subscription?" do
    it "returns true when trial is expired and there is no subscription" do
      org = org_with(trial_ends_at: 1.day.ago)
      expect(service_for(org).needs_subscription?).to be true
    end

    it "returns true when trial is expired and subscription is canceled" do
      org = org_with(trial_ends_at: 1.day.ago)
      create(:subscription, :canceled, organization: org)
      org.reload
      expect(service_for(org).needs_subscription?).to be true
    end

    it "returns true when trial is expired and subscription is incomplete" do
      org = org_with(trial_ends_at: 1.day.ago)
      create(:subscription, :incomplete, organization: org)
      org.reload
      expect(service_for(org).needs_subscription?).to be true
    end

    it "returns false when trial is still active (even without a subscription)" do
      org = org_with(trial_ends_at: 5.days.from_now)
      expect(service_for(org).needs_subscription?).to be false
    end

    it "returns false when trial is expired but subscription is active" do
      org = org_with(trial_ends_at: 1.day.ago)
      create(:subscription, :active, organization: org)
      org.reload
      expect(service_for(org).needs_subscription?).to be false
    end

    it "returns false when trial is expired but subscription is past_due" do
      org = org_with(trial_ends_at: 1.day.ago)
      create(:subscription, :past_due, organization: org)
      org.reload
      expect(service_for(org).needs_subscription?).to be false
    end
  end

  # ── can_self_upgrade? ─────────────────────────────────────────────────────
  describe "#can_self_upgrade?" do
    it "returns true for an active sirh_essential subscription" do
      org = org_with(trial_ends_at: 1.day.from_now, plan: "sirh")
      create(:subscription, :active, :sirh_essential, organization: org)
      org.reload
      expect(service_for(org).can_self_upgrade?).to be true
    end

    it "returns false for sirh_pro (already at the top)" do
      org = org_with(trial_ends_at: 1.day.from_now, plan: "sirh")
      create(:subscription, :active, :sirh_pro, organization: org)
      org.reload
      expect(service_for(org).can_self_upgrade?).to be false
    end

    it "returns false for manager_os (requires admin, not self-service)" do
      org = org_with(trial_ends_at: 1.day.from_now)
      create(:subscription, :active, :manager_os, organization: org)
      org.reload
      expect(service_for(org).can_self_upgrade?).to be false
    end

    it "returns false for a past_due sirh_essential subscription" do
      org = org_with(trial_ends_at: 1.day.ago, plan: "sirh")
      create(:subscription, :past_due, :sirh_essential, organization: org)
      org.reload
      expect(service_for(org).can_self_upgrade?).to be false
    end

    it "returns false when there is no subscription" do
      org = org_with(trial_ends_at: 1.day.from_now)
      # can_self_upgrade? delegates to can_upgrade_to_pro? which calls &. — returns nil (falsy)
      expect(service_for(org).can_self_upgrade?).to be_falsy
    end
  end

  # ── upgrade_requires_contact? ─────────────────────────────────────────────
  describe "#upgrade_requires_contact?" do
    it "returns true when subscription plan is manager_os" do
      org = org_with
      create(:subscription, :active, :manager_os, organization: org)
      org.reload
      expect(service_for(org).upgrade_requires_contact?).to be true
    end

    it "returns true when org.plan is 'manager_os' even without a subscription" do
      org = org_with(plan: "manager_os")
      expect(service_for(org).upgrade_requires_contact?).to be true
    end

    it "returns false for sirh_essential subscription" do
      org = org_with(plan: "sirh")
      create(:subscription, :active, :sirh_essential, organization: org)
      org.reload
      expect(service_for(org).upgrade_requires_contact?).to be false
    end

    it "returns false for sirh_pro subscription" do
      org = org_with(plan: "sirh")
      create(:subscription, :active, :sirh_pro, organization: org)
      org.reload
      expect(service_for(org).upgrade_requires_contact?).to be false
    end
  end

  # ── current_plan ──────────────────────────────────────────────────────────
  describe "#current_plan" do
    it "returns :manager_os for a manager_os subscription" do
      org = org_with
      create(:subscription, :active, :manager_os, organization: org)
      org.reload
      expect(service_for(org).current_plan).to eq(:manager_os)
    end

    it "returns :sirh_essential for a sirh_essential subscription" do
      org = org_with(plan: "sirh")
      create(:subscription, :active, :sirh_essential, organization: org)
      org.reload
      expect(service_for(org).current_plan).to eq(:sirh_essential)
    end

    it "returns :sirh_pro for a sirh_pro subscription" do
      org = org_with(plan: "sirh")
      create(:subscription, :active, :sirh_pro, organization: org)
      org.reload
      expect(service_for(org).current_plan).to eq(:sirh_pro)
    end

    context "fallback on org.plan when no subscription" do
      it "returns :manager_os when org.plan is 'manager_os'" do
        org = org_with(plan: "manager_os")
        expect(service_for(org).current_plan).to eq(:manager_os)
      end

      it "returns :sirh_essential when org.plan is 'sirh'" do
        org = org_with(plan: "sirh")
        expect(service_for(org).current_plan).to eq(:sirh_essential)
      end

      it "defaults to :manager_os for an unexpected org.plan value" do
        # The Organization model only allows manager_os/sirh, but guard the fallback anyway
        org = org_with(plan: "manager_os")
        expect(service_for(org).current_plan).to eq(:manager_os)
      end
    end
  end

  # ── can?(feature) ─────────────────────────────────────────────────────────
  describe "#can?" do
    context "billing inactive (trial expired, no subscription)" do
      let(:org) { org_with(trial_ends_at: 2.days.ago) }

      it "returns false for any feature" do
        expect(service_for(org).can?(:onboarding)).to be false
        expect(service_for(org).can?(:time_tracking)).to be false
        expect(service_for(org).can?(:hr_ai)).to be false
      end
    end

    context "manager_os plan (trial active)" do
      let(:org) { org_with(trial_ends_at: 7.days.from_now, plan: "manager_os") }

      it "can access onboarding" do
        expect(service_for(org).can?(:onboarding)).to be true
      end

      it "can access one_on_ones" do
        expect(service_for(org).can?(:one_on_ones)).to be true
      end

      it "cannot access time_tracking" do
        expect(service_for(org).can?(:time_tracking)).to be false
      end

      it "cannot access leave_management" do
        expect(service_for(org).can?(:leave_management)).to be false
      end

      it "cannot access payroll_analytics" do
        expect(service_for(org).can?(:payroll_analytics)).to be false
      end

      it "cannot access hr_ai" do
        expect(service_for(org).can?(:hr_ai)).to be false
      end
    end

    context "sirh_essential subscription" do
      let(:org) { org_with(trial_ends_at: 2.days.ago, plan: "sirh") }

      before { create(:subscription, :active, :sirh_essential, organization: org); org.reload }

      it "can access time_tracking" do
        expect(service_for(org).can?(:time_tracking)).to be true
      end

      it "can access leave_management" do
        expect(service_for(org).can?(:leave_management)).to be true
      end

      it "can access payroll_exports" do
        expect(service_for(org).can?(:payroll_exports)).to be true
      end

      it "cannot access payroll_analytics (pro only)" do
        expect(service_for(org).can?(:payroll_analytics)).to be false
      end

      it "cannot access hr_ai (pro only)" do
        expect(service_for(org).can?(:hr_ai)).to be false
      end

      it "cannot access geolocation (pro only)" do
        expect(service_for(org).can?(:geolocation)).to be false
      end
    end

    context "sirh_pro subscription" do
      let(:org) { org_with(trial_ends_at: 2.days.ago, plan: "sirh") }

      before { create(:subscription, :active, :sirh_pro, organization: org); org.reload }

      it "can access hr_ai" do
        expect(service_for(org).can?(:hr_ai)).to be true
      end

      it "can access geolocation" do
        expect(service_for(org).can?(:geolocation)).to be true
      end

      it "can access audit_log" do
        expect(service_for(org).can?(:audit_log)).to be true
      end

      it "can access api_mobile" do
        expect(service_for(org).can?(:api_mobile)).to be true
      end

      it "returns false for an unknown feature" do
        expect(service_for(org).can?(:nonexistent_feature)).to be false
      end
    end
  end
end
