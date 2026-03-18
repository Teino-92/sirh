# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OnboardingTemplatePolicy, type: :policy do
  let(:manager_os_org) { create(:organization, plan: 'manager_os') }
  let(:sirh_org)       { create(:organization, plan: 'sirh') }

  let(:hr_manager_os)      { create(:employee, organization: manager_os_org, role: 'hr') }
  let(:admin_manager_os)   { create(:employee, organization: manager_os_org, role: 'admin') }
  let(:manager_manager_os) { create(:employee, organization: manager_os_org, role: 'manager') }
  let(:employee_manager_os){ create(:employee, organization: manager_os_org) }

  let(:hr_sirh)      { create(:employee, organization: sirh_org, role: 'hr') }
  let(:admin_sirh)   { create(:employee, organization: sirh_org, role: 'admin') }
  let(:manager_sirh) { create(:employee, organization: sirh_org, role: 'manager') }

  let(:template_manager_os) do
    ActsAsTenant.with_tenant(manager_os_org) do
      create(:onboarding_template, organization: manager_os_org)
    end
  end

  let(:template_sirh) do
    ActsAsTenant.with_tenant(sirh_org) do
      create(:onboarding_template, organization: sirh_org)
    end
  end

  # Template non persisté (pour les tests de create? avec new record)
  let(:new_template_manager_os) { OnboardingTemplate.new(organization: manager_os_org) }
  let(:new_template_sirh)       { OnboardingTemplate.new(organization: sirh_org) }

  subject { described_class }

  # ── Scope ─────────────────────────────────────────────────────────────────
  describe 'Scope' do
    before { template_manager_os; template_sirh }

    it 'restricts to current organization active templates' do
      ActsAsTenant.with_tenant(manager_os_org) do
        resolved = OnboardingTemplatePolicy::Scope.new(hr_manager_os, OnboardingTemplate).resolve
        expect(resolved).to include(template_manager_os)
      end
    end

    it 'does not include templates from another org' do
      ActsAsTenant.with_tenant(manager_os_org) do
        resolved = OnboardingTemplatePolicy::Scope.new(hr_manager_os, OnboardingTemplate).resolve
        expect(resolved).not_to include(template_sirh)
      end
    end
  end

  # ── index? / show? ────────────────────────────────────────────────────────
  permissions :index?, :show? do
    it 'permits HR on Manager OS' do
      expect(subject).to permit(hr_manager_os, template_manager_os)
    end

    it 'permits admin on Manager OS' do
      expect(subject).to permit(admin_manager_os, template_manager_os)
    end

    it 'permits manager on Manager OS' do
      expect(subject).to permit(manager_manager_os, template_manager_os)
    end

    it 'denies plain employee' do
      expect(subject).not_to permit(employee_manager_os, template_manager_os)
    end

    it 'permits HR on SIRH' do
      expect(subject).to permit(hr_sirh, template_sirh)
    end

    it 'permits manager on SIRH (read-only)' do
      expect(subject).to permit(manager_sirh, template_sirh)
    end
  end

  # ── create? / update? / destroy? ─────────────────────────────────────────
  permissions :create?, :update?, :destroy? do
    context 'on Manager OS org' do
      it 'permits HR' do
        expect(subject).to permit(hr_manager_os, template_manager_os)
      end

      it 'permits admin' do
        expect(subject).to permit(admin_manager_os, template_manager_os)
      end

      it 'permits manager — core feature of Manager OS' do
        expect(subject).to permit(manager_manager_os, template_manager_os)
      end

      it 'denies plain employee' do
        expect(subject).not_to permit(employee_manager_os, template_manager_os)
      end

      it 'permits manager with non-persisted template (new record)' do
        expect(subject).to permit(manager_manager_os, new_template_manager_os)
      end
    end

    context 'on SIRH org' do
      it 'permits HR' do
        expect(subject).to permit(hr_sirh, template_sirh)
      end

      it 'permits admin' do
        expect(subject).to permit(admin_sirh, template_sirh)
      end

      it 'denies manager — templates managed by HR/Admin on SIRH' do
        expect(subject).not_to permit(manager_sirh, template_sirh)
      end

      it 'denies manager with non-persisted template on SIRH' do
        expect(subject).not_to permit(manager_sirh, new_template_sirh)
      end
    end
  end
end
