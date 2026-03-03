# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeeOnboardingProgressCalculatorService do
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
    context 'when there are no tasks' do
      it 'returns 0' do
        ActsAsTenant.with_tenant(organization) do
          expect(service.call).to eq(0)
        end
      end
    end

    context 'when all tasks are pending' do
      before { 3.times { create_task(status: 'pending', task_type: 'manual') } }

      it 'returns 0' do
        ActsAsTenant.with_tenant(organization) do
          expect(service.call).to eq(0)
        end
      end
    end

    context 'when all tasks are completed' do
      before { 2.times { create_task(status: 'completed', task_type: 'manual') } }

      it 'returns 100' do
        ActsAsTenant.with_tenant(organization) do
          expect(service.call).to eq(100)
        end
      end
    end

    context 'proportional progress — 1 of 4 tasks completed' do
      before do
        create_task(status: 'completed', task_type: 'manual')
        3.times { create_task(status: 'pending', task_type: 'manual') }
      end

      it 'returns 25' do
        ActsAsTenant.with_tenant(organization) do
          expect(service.call).to eq(25)
        end
      end
    end

    context 'with linked training assignments' do
      let(:training) { create(:training, organization: organization) }

      before do
        ta_completed = create(:training_assignment,
                              training: training,
                              employee: employee,
                              assigned_by: manager,
                              status: :completed)
        ta_pending   = create(:training_assignment,
                              training: training,
                              employee: employee,
                              assigned_by: manager,
                              status: :assigned)

        create_task(task_type: 'training', status: 'pending',
                    metadata: { 'linked_training_assignment_id' => ta_completed.id })
        create_task(task_type: 'training', status: 'pending',
                    metadata: { 'linked_training_assignment_id' => ta_pending.id })
      end

      it 'counts completed training assignments' do
        ActsAsTenant.with_tenant(organization) do
          # 4 total (2 tasks + 2 training assignments), 1 done (ta_completed)
          expect(service.call).to eq(25)
        end
      end
    end

    context 'with linked objectives' do
      before do
        obj_done = create(:objective, :completed,
                          organization: organization,
                          manager: manager,
                          created_by: manager,
                          owner: employee)
        obj_open = create(:objective,
                          organization: organization,
                          manager: manager,
                          created_by: manager,
                          owner: employee)

        create_task(task_type: 'objective_30', status: 'pending',
                    metadata: { 'linked_objective_id' => obj_done.id })
        create_task(task_type: 'objective_60', status: 'pending',
                    metadata: { 'linked_objective_id' => obj_open.id })
      end

      it 'counts completed objectives' do
        ActsAsTenant.with_tenant(organization) do
          # 4 total (2 tasks + 2 objectives), 1 done (obj_done)
          expect(service.call).to eq(25)
        end
      end
    end

    context 'with linked one_on_ones' do
      before do
        oo_completed = create(:one_on_one, :completed,
                              organization: organization,
                              manager: manager,
                              employee: employee)
        oo_scheduled = create(:one_on_one,
                              organization: organization,
                              manager: manager,
                              employee: employee)

        create_task(task_type: 'one_on_one', status: 'pending',
                    metadata: { 'linked_one_on_one_id' => oo_completed.id })
        create_task(task_type: 'one_on_one', status: 'pending',
                    metadata: { 'linked_one_on_one_id' => oo_scheduled.id })
      end

      it 'counts completed one_on_ones' do
        ActsAsTenant.with_tenant(organization) do
          # 4 total (2 tasks + 2 one_on_ones), 1 done (oo_completed)
          expect(service.call).to eq(25)
        end
      end
    end

    context 'with mixed task types — all done' do
      let(:training) { create(:training, organization: organization) }

      before do
        ta = create(:training_assignment, :completed,
                    training: training, employee: employee, assigned_by: manager)
        oo = create(:one_on_one, :completed,
                    organization: organization, manager: manager, employee: employee)
        obj = create(:objective, :completed,
                     organization: organization, manager: manager, created_by: manager, owner: employee)

        create_task(status: 'completed', task_type: 'manual')
        create_task(task_type: 'training',     status: 'completed',
                    metadata: { 'linked_training_assignment_id' => ta.id })
        create_task(task_type: 'one_on_one',   status: 'completed',
                    metadata: { 'linked_one_on_one_id' => oo.id })
        create_task(task_type: 'objective_90', status: 'completed',
                    metadata: { 'linked_objective_id' => obj.id })
      end

      it 'returns 100' do
        ActsAsTenant.with_tenant(organization) do
          expect(service.call).to eq(100)
        end
      end
    end

    context 'no N+1 — loads tasks once' do
      before do
        5.times { create_task(status: 'pending', task_type: 'manual') }
      end

      it 'queries tasks exactly once' do
        ActsAsTenant.with_tenant(organization) do
          query_count = 0
          counter = ->(_name, _start, _finish, _id, payload) do
            query_count += 1 if payload[:sql]&.include?('onboarding_tasks')
          end

          ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
            service.call
          end

          expect(query_count).to eq(1)
        end
      end
    end
  end
end
