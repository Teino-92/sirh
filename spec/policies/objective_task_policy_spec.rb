# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObjectiveTaskPolicy, type: :policy do
  let(:org)       { create(:organization) }
  let(:manager)   { create(:employee, :manager, organization: org) }
  let(:employee)  { create(:employee, organization: org) }
  let(:other_emp) { create(:employee, organization: org) }

  let(:objective) do
    ActsAsTenant.with_tenant(org) do
      create(:objective, organization: org, manager: manager, owner: employee, created_by: manager)
    end
  end

  let(:todo_task) do
    ActsAsTenant.with_tenant(org) do
      create(:objective_task, organization: org, objective: objective, assigned_to: employee)
    end
  end

  let(:done_task) do
    ActsAsTenant.with_tenant(org) do
      create(:objective_task, :done, organization: org, objective: objective, assigned_to: employee)
    end
  end

  let(:validated_task) do
    ActsAsTenant.with_tenant(org) do
      create(:objective_task, :validated, organization: org, objective: objective, assigned_to: employee)
    end
  end

  subject { described_class }

  describe 'manager permissions' do
    permissions :create? do
      it 'allows manager of the objective to create tasks' do
        expect(subject).to permit(manager, todo_task)
      end
    end

    permissions :destroy? do
      it 'allows manager to destroy a todo task' do
        expect(subject).to permit(manager, todo_task)
      end

      it 'denies manager from destroying a validated task' do
        expect(subject).not_to permit(manager, validated_task)
      end
    end

    permissions :complete? do
      it 'denies manager from completing a task' do
        expect(subject).not_to permit(manager, todo_task)
      end
    end

    permissions :validate_task? do
      it 'allows manager to validate a done task' do
        expect(subject).to permit(manager, done_task)
      end

      it 'denies manager from validating a not-done task' do
        expect(subject).not_to permit(manager, todo_task)
      end
    end
  end

  describe 'employee permissions — assigned' do
    permissions :create? do
      it 'denies employee from creating tasks' do
        expect(subject).not_to permit(employee, todo_task)
      end
    end

    permissions :destroy? do
      it 'denies employee from destroying tasks' do
        expect(subject).not_to permit(employee, todo_task)
      end
    end

    permissions :validate_task? do
      it 'denies employee from validating tasks' do
        expect(subject).not_to permit(employee, todo_task)
      end
    end

    permissions :complete? do
      it 'allows assigned employee to complete a todo task' do
        expect(subject).to permit(employee, todo_task)
      end

      it 'denies assigned employee from completing a validated task' do
        expect(subject).not_to permit(employee, validated_task)
      end
    end
  end

  describe 'employee permissions — not assigned' do
    permissions :complete? do
      it 'denies non-assigned employee from completing the task' do
        expect(subject).not_to permit(other_emp, todo_task)
      end
    end
  end
end
