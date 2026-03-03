# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeeOnboardingInitializerService do
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
             start_date: Date.new(2026, 3, 1),
             end_date:   Date.new(2026, 5, 30))
    end
  end

  subject(:service) { described_class.new(onboarding) }

  describe '#call' do
    context 'when template has no tasks' do
      it 'creates no onboarding_tasks' do
        ActsAsTenant.with_tenant(organization) do
          expect { service.call }.not_to change(OnboardingTask, :count)
        end
      end
    end

    context 'with a manual task' do
      let!(:template_task) do
        ActsAsTenant.with_tenant(organization) do
          create(:onboarding_template_task,
                 onboarding_template: template,
                 organization: organization,
                 title: 'Setup laptop',
                 due_day_offset: 1,
                 task_type: 'manual',
                 assigned_to_role: 'hr',
                 position: 0)
        end
      end

      it 'creates one OnboardingTask' do
        ActsAsTenant.with_tenant(organization) do
          expect { service.call }.to change(OnboardingTask, :count).by(1)
        end
      end

      it 'sets the correct due_date from start_date + offset' do
        ActsAsTenant.with_tenant(organization) do
          service.call
          task = onboarding.reload.onboarding_tasks.first
          expect(task.due_date).to eq(Date.new(2026, 3, 2))
        end
      end

      it 'sets the correct organization on the task' do
        ActsAsTenant.with_tenant(organization) do
          service.call
          task = onboarding.reload.onboarding_tasks.first
          expect(task.organization).to eq(organization)
        end
      end

      it 'leaves metadata empty for manual tasks' do
        ActsAsTenant.with_tenant(organization) do
          service.call
          task = onboarding.reload.onboarding_tasks.first
          expect(task.metadata).to eq({})
        end
      end
    end

    context 'idempotency — called twice' do
      let!(:template_task) do
        ActsAsTenant.with_tenant(organization) do
          create(:onboarding_template_task,
                 onboarding_template: template,
                 organization: organization,
                 due_day_offset: 1,
                 task_type: 'manual',
                 assigned_to_role: 'manager')
        end
      end

      it 'does not create duplicate tasks on a second call' do
        ActsAsTenant.with_tenant(organization) do
          service.call
          expect { service.call }.not_to change(OnboardingTask, :count)
        end
      end
    end

    context 'with an objective_30 task' do
      let!(:template_task) do
        ActsAsTenant.with_tenant(organization) do
          create(:onboarding_template_task, :objective_30,
                 onboarding_template: template,
                 organization: organization)
        end
      end

      it 'creates an Objective linked to the employee' do
        ActsAsTenant.with_tenant(organization) do
          expect { service.call }.to change(Objective, :count).by(1)
          objective = Objective.last
          expect(objective.owner).to eq(employee)
          expect(objective.manager).to eq(manager)
          expect(objective.organization).to eq(organization)
        end
      end

      it 'stores linked_objective_id in task metadata' do
        ActsAsTenant.with_tenant(organization) do
          service.call
          task = onboarding.reload.onboarding_tasks.first
          expect(task.metadata['linked_objective_id']).to be_present
          expect(Objective.find_by(id: task.metadata['linked_objective_id'])).not_to be_nil
        end
      end
    end

    context 'with a one_on_one task' do
      let!(:template_task) do
        ActsAsTenant.with_tenant(organization) do
          create(:onboarding_template_task, :one_on_one,
                 onboarding_template: template,
                 organization: organization)
        end
      end

      it 'creates a OneOnOne linked to the manager and employee' do
        ActsAsTenant.with_tenant(organization) do
          expect { service.call }.to change(OneOnOne, :count).by(1)
          oo = OneOnOne.last
          expect(oo.manager).to eq(manager)
          expect(oo.employee).to eq(employee)
          expect(oo.organization).to eq(organization)
        end
      end

      it 'schedules the OneOnOne at 10:00 UTC on the due date' do
        ActsAsTenant.with_tenant(organization) do
          service.call
          oo = OneOnOne.last
          expect(oo.scheduled_at.utc.hour).to eq(10)
        end
      end

      it 'stores linked_one_on_one_id in task metadata' do
        ActsAsTenant.with_tenant(organization) do
          service.call
          task = onboarding.reload.onboarding_tasks.first
          expect(task.metadata['linked_one_on_one_id']).to be_present
        end
      end
    end

    context 'with a training task (training_id set in metadata)' do
      let(:training) { create(:training, organization: organization) }
      let!(:template_task) do
        ActsAsTenant.with_tenant(organization) do
          create(:onboarding_template_task, :training,
                 onboarding_template: template,
                 organization: organization,
                 metadata: { 'training_id' => nil }) # overridden below
        end
      end

      before do
        ActsAsTenant.with_tenant(organization) do
          template_task.update!(metadata: { 'training_id' => training.id })
        end
      end

      it 'creates a TrainingAssignment linked to the employee' do
        ActsAsTenant.with_tenant(organization) do
          expect { service.call }.to change(TrainingAssignment, :count).by(1)
          ta = TrainingAssignment.last
          expect(ta.employee).to eq(employee)
          expect(ta.assigned_by).to eq(manager)
          expect(ta.training).to eq(training)
        end
      end

      it 'stores linked_training_assignment_id in task metadata' do
        ActsAsTenant.with_tenant(organization) do
          service.call
          task = onboarding.reload.onboarding_tasks.first
          expect(task.metadata['linked_training_assignment_id']).to be_present
        end
      end
    end

    context 'with a training task and no training_id in metadata' do
      let!(:template_task) do
        ActsAsTenant.with_tenant(organization) do
          create(:onboarding_template_task, :training,
                 onboarding_template: template,
                 organization: organization,
                 metadata: {})
        end
      end

      it 'creates the OnboardingTask but no TrainingAssignment' do
        ActsAsTenant.with_tenant(organization) do
          expect { service.call }.to change(OnboardingTask, :count).by(1)
          expect(TrainingAssignment.count).to eq(0)
        end
      end
    end

    context 'transaction safety — rollback on failure' do
      let!(:template_task) do
        ActsAsTenant.with_tenant(organization) do
          create(:onboarding_template_task, :objective_30,
                 onboarding_template: template,
                 organization: organization)
        end
      end

      it 'rolls back OnboardingTask creation when Objective creation fails' do
        allow(Objective).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(Objective.new))

        ActsAsTenant.with_tenant(organization) do
          expect {
            service.call rescue nil
          }.not_to change(OnboardingTask, :count)
        end
      end
    end

    context 'tenant isolation' do
      let(:other_org)      { create(:organization) }
      let(:other_manager)  { create(:employee, :manager, organization: other_org) }
      let(:other_employee) { create(:employee, organization: other_org) }
      let(:other_template) { create(:onboarding_template, organization: other_org) }
      let!(:template_task) do
        ActsAsTenant.with_tenant(organization) do
          create(:onboarding_template_task,
                 onboarding_template: template,
                 organization: organization,
                 due_day_offset: 1,
                 task_type: 'manual',
                 assigned_to_role: 'hr')
        end
      end
      let!(:other_template_task) do
        ActsAsTenant.with_tenant(other_org) do
          create(:onboarding_template_task,
                 onboarding_template: other_template,
                 organization: other_org,
                 due_day_offset: 1,
                 task_type: 'manual',
                 assigned_to_role: 'hr')
        end
      end
      let(:other_onboarding) do
        ActsAsTenant.with_tenant(other_org) do
          create(:employee_onboarding,
                 organization: other_org,
                 employee: other_employee,
                 manager: other_manager,
                 onboarding_template: other_template,
                 start_date: Date.new(2026, 3, 1),
                 end_date:   Date.new(2026, 5, 30))
        end
      end

      it 'does not create tasks across organizations' do
        ActsAsTenant.with_tenant(organization) { service.call }

        ActsAsTenant.with_tenant(other_org) do
          expect(other_onboarding.onboarding_tasks.count).to eq(0)
        end
      end
    end
  end
end
