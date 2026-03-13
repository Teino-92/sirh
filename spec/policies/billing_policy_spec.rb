# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingPolicy, type: :policy do
  # ── Setup principal ────────────────────────────────────────────────────────
  let(:organization) { create(:organization, trial_ends_at: 7.days.from_now) }
  let(:admin)        { create(:employee, organization: organization, role: "admin") }
  let(:hr)           { create(:employee, organization: organization, role: "hr") }
  let(:manager)      { create(:employee, organization: organization, role: "manager") }
  let(:employee)     { create(:employee, organization: organization) }

  # Org isolée — ne doit jamais être autorisée sur l'org principale
  let(:other_org)      { create(:organization) }
  let(:other_employee) { create(:employee, organization: other_org) }
  let(:other_admin)    { create(:employee, organization: other_org, role: "admin") }

  subject { described_class }

  # ── show? ─────────────────────────────────────────────────────────────────
  permissions :show? do
    it "permits admin" do
      expect(subject).to permit(admin, organization)
    end

    it "permits hr" do
      expect(subject).to permit(hr, organization)
    end

    it "permits manager" do
      expect(subject).to permit(manager, organization)
    end

    it "denies plain employee" do
      expect(subject).not_to permit(employee, organization)
    end

    it "denies an admin from another org" do
      expect(subject).not_to permit(other_admin, organization)
    end
  end

  # ── create_checkout? ──────────────────────────────────────────────────────
  permissions :create_checkout? do
    context "during trial" do
      it "permits admin" do
        expect(subject).to permit(admin, organization)
      end

      it "permits hr" do
        expect(subject).to permit(hr, organization)
      end

      it "permits manager while trial is active" do
        expect(subject).to permit(manager, organization)
      end

      it "denies plain employee even during trial" do
        expect(subject).not_to permit(employee, organization)
      end
    end

    context "trial expired" do
      let(:expired_org) do
        create(:organization, trial_ends_at: 2.days.ago)
      end
      let(:expired_admin)   { create(:employee, organization: expired_org, role: "admin") }
      let(:expired_hr)      { create(:employee, organization: expired_org, role: "hr") }
      let(:expired_manager) { create(:employee, organization: expired_org, role: "manager") }

      it "permits admin after trial expires" do
        expect(subject).to permit(expired_admin, expired_org)
      end

      it "permits hr after trial expires" do
        expect(subject).to permit(expired_hr, expired_org)
      end

      it "denies manager after trial expires" do
        expect(subject).not_to permit(expired_manager, expired_org)
      end
    end

    it "denies an admin from another org" do
      expect(subject).not_to permit(other_admin, organization)
    end

    it "denies an employee from another org" do
      expect(subject).not_to permit(other_employee, organization)
    end
  end

  # ── upgrade? ──────────────────────────────────────────────────────────────
  permissions :upgrade? do
    it "permits admin" do
      expect(subject).to permit(admin, organization)
    end

    it "permits hr" do
      expect(subject).to permit(hr, organization)
    end

    it "denies manager" do
      expect(subject).not_to permit(manager, organization)
    end

    it "denies plain employee" do
      expect(subject).not_to permit(employee, organization)
    end

    it "denies admin from another org" do
      expect(subject).not_to permit(other_admin, organization)
    end
  end

  # ── cancel? ───────────────────────────────────────────────────────────────
  permissions :cancel? do
    it "permits admin" do
      expect(subject).to permit(admin, organization)
    end

    it "permits hr" do
      expect(subject).to permit(hr, organization)
    end

    it "denies manager" do
      expect(subject).not_to permit(manager, organization)
    end

    it "denies plain employee" do
      expect(subject).not_to permit(employee, organization)
    end

    it "denies admin from another org" do
      expect(subject).not_to permit(other_admin, organization)
    end

    it "denies employee from another org" do
      expect(subject).not_to permit(other_employee, organization)
    end
  end

  # ── request_upgrade? ──────────────────────────────────────────────────────
  permissions :request_upgrade? do
    it "permits admin" do
      expect(subject).to permit(admin, organization)
    end

    it "permits hr" do
      expect(subject).to permit(hr, organization)
    end

    it "denies manager" do
      expect(subject).not_to permit(manager, organization)
    end

    it "denies plain employee" do
      expect(subject).not_to permit(employee, organization)
    end
  end

  # ── success? ──────────────────────────────────────────────────────────────
  permissions :success? do
    it "permits admin" do
      expect(subject).to permit(admin, organization)
    end

    it "permits hr" do
      expect(subject).to permit(hr, organization)
    end

    it "denies manager" do
      expect(subject).not_to permit(manager, organization)
    end

    it "denies plain employee" do
      expect(subject).not_to permit(employee, organization)
    end
  end

  # ── Isolation multi-tenant ────────────────────────────────────────────────
  # Each cross-tenant check must be inside a permissions block so Pundit/RSpec
  # knows which permission to evaluate.
  permissions :show? do
    it "denies an employee from another org" do
      expect(subject).not_to permit(other_employee, organization)
    end
  end

  permissions :cancel? do
    it "denies an admin from another org" do
      expect(subject).not_to permit(other_admin, organization)
    end
  end

  permissions :upgrade? do
    it "denies an admin from another org" do
      expect(subject).not_to permit(other_admin, organization)
    end
  end

  permissions :create_checkout? do
    it "denies an admin from another org" do
      expect(subject).not_to permit(other_admin, organization)
    end
  end
end
