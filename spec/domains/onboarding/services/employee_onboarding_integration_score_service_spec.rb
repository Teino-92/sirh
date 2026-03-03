# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeeOnboardingIntegrationScoreService do
  # WEIGHTS: task=0.30, training=0.25, one_on_one=0.20, manager=0.25
  WEIGHTS = EmployeeOnboardingIntegrationScoreService::WEIGHTS

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
             onboarding_template: template)
    end
  end

  subject(:service) { described_class.new(onboarding) }

  def create_task(attrs = {})
    ActsAsTenant.with_tenant(organization) do
      create(:onboarding_task, { employee_onboarding: onboarding, organization: organization }.merge(attrs))
    end
  end

  describe '#call' do
    context 'when there is no data (all rates zero, no manager review)' do
      it 'returns 0' do
        ActsAsTenant.with_tenant(organization) do
          expect(service.call).to eq(0)
        end
      end
    end

    context 'score range is always 0–100' do
      it 'returns 0 with no completed items' do
        ActsAsTenant.with_tenant(organization) do
          create_task(status: 'pending', task_type: 'manual')
          score = service.call
          expect(score).to be_between(0, 100)
          expect(score).to eq(0)
        end
      end

      it 'returns 100 when everything is completed with perfect manager review' do
        ActsAsTenant.with_tenant(organization) do
          training = create(:training, organization: organization)
          ta = create(:training_assignment, :completed,
                      training: training, employee: employee, assigned_by: manager)
          oo = create(:one_on_one, :completed,
                      organization: organization, manager: manager, employee: employee)

          create_task(status: 'completed', task_type: 'manual')
          create_task(task_type: 'training',   status: 'completed',
                      metadata: { 'linked_training_assignment_id' => ta.id })
          create_task(task_type: 'one_on_one', status: 'completed',
                      metadata: { 'linked_one_on_one_id' => oo.id })

          # integration_level = 5 → (5.0 - 1) / 4 = 1.0
          create(:onboarding_review, :manager_review,
                 employee_onboarding: onboarding,
                 organization: organization,
                 manager_feedback_json: { 'integration_level' => 5 })

          score = service.call
          expect(score).to eq(100)
        end
      end
    end

    context 'weight redistribution when no manager review' do
      it 'redistributes manager weight proportionally across the 3 other components' do
        extra = WEIGHTS[:manager]  # 0.25
        non_manager_sum = WEIGHTS[:task] + WEIGHTS[:training] + WEIGHTS[:one_on_one]  # 0.75

        expected_task_w      = WEIGHTS[:task]      + extra * (WEIGHTS[:task]      / non_manager_sum)
        expected_training_w  = WEIGHTS[:training]  + extra * (WEIGHTS[:training]  / non_manager_sum)
        expected_oo_w        = WEIGHTS[:one_on_one] + extra * (WEIGHTS[:one_on_one] / non_manager_sum)

        expect(expected_task_w + expected_training_w + expected_oo_w).to be_within(0.001).of(1.0)
      end

      it 'returns a non-zero score when only tasks are completed (no manager review)' do
        ActsAsTenant.with_tenant(organization) do
          create_task(status: 'completed', task_type: 'manual')

          score = service.call
          # task_rate=1.0, training_rate=0, oo_rate=0, manager_rate=nil
          # effective task weight = 0.30 + 0.25*(0.30/0.75) = 0.30 + 0.10 = 0.40
          expect(score).to eq(40)
        end
      end
    end

    context 'with a manager review (integration_level 4 out of 5)' do
      before do
        ActsAsTenant.with_tenant(organization) do
          create(:onboarding_review, :manager_review,
                 employee_onboarding: onboarding,
                 organization: organization,
                 manager_feedback_json: { 'integration_level' => 4 })
        end
      end

      it 'uses the manager weight from WEIGHTS (no redistribution)' do
        ActsAsTenant.with_tenant(organization) do
          # All rates = 0 except manager = (4-1)/4 = 0.75
          # score = 0*0.30 + 0*0.25 + 0*0.20 + 0.75*0.25 = 0.1875 → round → 19
          score = service.call
          expect(score).to eq(19)
        end
      end
    end

    context 'with only training completions' do
      let(:training) { create(:training, organization: organization) }

      before do
        ActsAsTenant.with_tenant(organization) do
          ta = create(:training_assignment, :completed,
                      training: training, employee: employee, assigned_by: manager)
          create_task(task_type: 'training', status: 'pending',
                      metadata: { 'linked_training_assignment_id' => ta.id })
        end
      end

      it 'calculates score using redistributed weights' do
        ActsAsTenant.with_tenant(organization) do
          # training_rate=1.0, all others=0, no manager review
          # effective training weight = 0.25 + 0.25*(0.25/0.75) ≈ 0.333
          score = service.call
          expected = (1.0 * (0.25 + 0.25 * (0.25 / 0.75)) * 100).round
          expect(score).to eq(expected)
        end
      end
    end

    context 'with only completed one_on_ones' do
      before do
        ActsAsTenant.with_tenant(organization) do
          oo = create(:one_on_one, :completed,
                      organization: organization, manager: manager, employee: employee)
          create_task(task_type: 'one_on_one', status: 'pending',
                      metadata: { 'linked_one_on_one_id' => oo.id })
        end
      end

      it 'calculates score using redistributed weights for one_on_one' do
        ActsAsTenant.with_tenant(organization) do
          # oo_rate=1.0, all others=0, no manager review
          # effective oo weight = 0.20 + 0.25*(0.20/0.75) ≈ 0.2667
          score = service.call
          expected = (1.0 * (0.20 + 0.25 * (0.20 / 0.75)) * 100).round
          expect(score).to eq(expected)
        end
      end
    end

    context 'tenant isolation' do
      let(:other_org)      { create(:organization) }
      let(:other_manager)  { create(:employee, :manager, organization: other_org) }
      let(:other_employee) { create(:employee, organization: other_org) }
      let(:other_template) { create(:onboarding_template, organization: other_org) }

      it "does not bleed other org's reviews into the score" do
        ActsAsTenant.with_tenant(other_org) do
          other_onboarding = create(:employee_onboarding,
                                    organization: other_org,
                                    employee: other_employee,
                                    manager: other_manager,
                                    onboarding_template: other_template)
          create(:onboarding_review, :manager_review,
                 employee_onboarding: other_onboarding,
                 organization: other_org,
                 manager_feedback_json: { 'integration_level' => 5 })
        end

        ActsAsTenant.with_tenant(organization) do
          # our onboarding has no review, so manager_rate should be nil
          score = service.call
          # task_rate=0, training=0, oo=0, manager=nil (no review for our onboarding)
          expect(score).to eq(0)
        end
      end
    end
  end
end
