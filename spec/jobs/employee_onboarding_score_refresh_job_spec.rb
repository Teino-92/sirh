# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeeOnboardingScoreRefreshJob do
  let(:organization) { create(:organization) }
  let(:manager)      { create(:employee, :manager, organization: organization) }
  let(:employee)     { create(:employee, organization: organization) }
  let(:template)     { create(:onboarding_template, organization: organization) }

  let(:onboarding) do
    ActsAsTenant.with_tenant(organization) do
      create(:employee_onboarding,
             organization: organization,
             employee: employee,
             manager: manager,
             onboarding_template: template,
             status: 'active',
             progress_percentage_cache: 0,
             integration_score_cache:   0)
    end
  end

  subject(:job) { described_class.new }

  describe '#perform' do
    context 'when the onboarding exists and is active' do
      it 'updates progress_percentage_cache' do
        ActsAsTenant.with_tenant(organization) do
          allow(EmployeeOnboardingProgressCalculatorService).to receive(:new).and_return(
            double(call: 42)
          )
          allow(EmployeeOnboardingIntegrationScoreService).to receive(:new).and_return(
            double(call: 37)
          )

          job.perform(onboarding.id)

          onboarding.reload
          expect(onboarding.progress_percentage_cache).to eq(42)
          expect(onboarding.integration_score_cache).to eq(37)
        end
      end

      it 'calls both services with the onboarding' do
        ActsAsTenant.with_tenant(organization) do
          progress_service = double(call: 50)
          score_service    = double(call: 60)

          expect(EmployeeOnboardingProgressCalculatorService).to receive(:new).with(onboarding).and_return(progress_service)
          expect(EmployeeOnboardingIntegrationScoreService).to  receive(:new).with(onboarding).and_return(score_service)

          job.perform(onboarding.id)
        end
      end

      it 'uses update_columns (no callbacks triggered)' do
        ActsAsTenant.with_tenant(organization) do
          allow(EmployeeOnboardingProgressCalculatorService).to receive(:new).and_return(double(call: 10))
          allow(EmployeeOnboardingIntegrationScoreService).to  receive(:new).and_return(double(call: 20))

          expect(onboarding).not_to receive(:save)
          expect(onboarding).not_to receive(:update)

          job.perform(onboarding.id)
        end
      end
    end

    context 'when the onboarding does not exist' do
      it 'discards the job silently (no exception raised)' do
        expect { job.perform(999_999) }.not_to raise_error
      end

      it 'does not call any service' do
        expect(EmployeeOnboardingProgressCalculatorService).not_to receive(:new)
        expect(EmployeeOnboardingIntegrationScoreService).not_to  receive(:new)

        job.perform(999_999)
      end
    end

    context 'when the onboarding is not active (completed)' do
      before do
        ActsAsTenant.with_tenant(organization) do
          onboarding.update_columns(status: 'completed')
        end
      end

      it 'returns early without calling services' do
        ActsAsTenant.with_tenant(organization) do
          expect(EmployeeOnboardingProgressCalculatorService).not_to receive(:new)
          expect(EmployeeOnboardingIntegrationScoreService).not_to  receive(:new)

          job.perform(onboarding.id)
        end
      end

      it 'does not modify cache columns' do
        ActsAsTenant.with_tenant(organization) do
          job.perform(onboarding.id)

          onboarding.reload
          expect(onboarding.progress_percentage_cache).to eq(0)
          expect(onboarding.integration_score_cache).to eq(0)
        end
      end
    end

    context 'when the onboarding is cancelled' do
      before do
        ActsAsTenant.with_tenant(organization) do
          onboarding.update_columns(status: 'cancelled')
        end
      end

      it 'returns early without calling services' do
        ActsAsTenant.with_tenant(organization) do
          expect(EmployeeOnboardingProgressCalculatorService).not_to receive(:new)
          job.perform(onboarding.id)
        end
      end
    end

    context 'idempotency — called multiple times with same id' do
      it 'produces the same result on each call' do
        ActsAsTenant.with_tenant(organization) do
          allow(EmployeeOnboardingProgressCalculatorService).to receive(:new).and_return(double(call: 75))
          allow(EmployeeOnboardingIntegrationScoreService).to  receive(:new).and_return(double(call: 80))

          job.perform(onboarding.id)
          job.perform(onboarding.id)

          onboarding.reload
          expect(onboarding.progress_percentage_cache).to eq(75)
          expect(onboarding.integration_score_cache).to eq(80)
        end
      end
    end
  end
end
