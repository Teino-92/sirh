# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TimeEntryPolicy, type: :policy do
  let(:organization) { create(:organization, plan: 'sirh') }
  let(:hr)           { create(:employee, organization: organization, role: 'hr') }
  let(:manager)      { create(:employee, organization: organization, role: 'manager') }
  let(:employee)     { create(:employee, organization: organization, manager: manager) }
  let(:other)        { create(:employee, organization: organization) }

  let(:entry) do
    ActsAsTenant.with_tenant(organization) do
      create(:time_entry, employee: employee, organization: organization)
    end
  end

  subject { described_class }

  context 'on manager_os plan' do
    let(:organization) { create(:organization, plan: 'manager_os') }

    permissions :index?, :clock_in? do
      it 'denies all (SIRH-only feature)' do
        expect(subject).not_to permit(hr, TimeEntry.new)
      end
    end
  end

  context 'on sirh plan' do
    describe 'Scope' do
      let!(:employee_entry) do
        ActsAsTenant.with_tenant(organization) { create(:time_entry, employee: employee, organization: organization) }
      end
      let!(:other_entry) do
        ActsAsTenant.with_tenant(organization) { create(:time_entry, employee: other, organization: organization) }
      end

      context 'as HR' do
        it 'returns all time entries' do
          resolved = TimeEntryPolicy::Scope.new(hr, TimeEntry).resolve
          expect(resolved).to include(employee_entry, other_entry)
        end
      end

      context 'as manager' do
        it 'returns own and team entries' do
          resolved = TimeEntryPolicy::Scope.new(manager, TimeEntry).resolve
          expect(resolved).to include(employee_entry)
          expect(resolved).not_to include(other_entry)
        end
      end

      context 'as plain employee' do
        it 'returns only own entries' do
          resolved = TimeEntryPolicy::Scope.new(employee, TimeEntry).resolve
          expect(resolved).to include(employee_entry)
          expect(resolved).not_to include(other_entry)
        end
      end
    end

    permissions :index? do
      it 'permits HR' do
        expect(subject).to permit(hr, TimeEntry.new)
      end

      it 'permits manager' do
        expect(subject).to permit(manager, TimeEntry.new)
      end

      it 'permits plain employee' do
        expect(subject).to permit(employee, TimeEntry.new)
      end
    end

    permissions :show? do
      it 'permits owner to view their own entry' do
        expect(subject).to permit(employee, entry)
      end

      it 'permits manager to view their report entry' do
        expect(subject).to permit(manager, entry)
      end

      it 'permits HR to view any entry' do
        expect(subject).to permit(hr, entry)
      end

      it 'denies other employee' do
        expect(subject).not_to permit(other, entry)
      end
    end

    permissions :create? do
      it 'permits owner to create their own entry' do
        new_entry = ActsAsTenant.with_tenant(organization) { build(:time_entry, employee: employee) }
        expect(subject).to permit(employee, new_entry)
      end

      it 'denies creating an entry for another employee' do
        other_entry = ActsAsTenant.with_tenant(organization) { build(:time_entry, employee: other) }
        expect(subject).not_to permit(employee, other_entry)
      end
    end

    permissions :update?, :destroy? do
      it 'denies employees from updating' do
        expect(subject).not_to permit(employee, entry)
      end

      it 'denies managers from updating' do
        expect(subject).not_to permit(manager, entry)
      end

      it 'denies HR from updating' do
        expect(subject).not_to permit(hr, entry)
      end
    end

    permissions :clock_in? do
      it 'permits any sirh user to clock in' do
        expect(subject).to permit(employee, TimeEntry.new)
        expect(subject).to permit(manager, TimeEntry.new)
      end
    end

    permissions :clock_out? do
      it 'permits owner to clock out their entry' do
        expect(subject).to permit(employee, entry)
      end

      it 'denies manager from clocking out their report entry' do
        expect(subject).not_to permit(manager, entry)
      end
    end

    permissions :validate? do
      it 'permits HR to validate' do
        expect(subject).to permit(hr, entry)
      end

      it 'permits manager to validate their report entry' do
        expect(subject).to permit(manager, entry)
      end

      it 'denies plain employee from validating' do
        expect(subject).not_to permit(employee, entry)
      end

      it 'denies manager from validating outside their team' do
        other_entry = ActsAsTenant.with_tenant(organization) { create(:time_entry, employee: other, organization: organization) }
        expect(subject).not_to permit(manager, other_entry)
      end
    end

    permissions :edit_as_admin? do
      it 'permits HR' do
        expect(subject).to permit(hr, entry)
      end

      it 'permits admin' do
        admin = create(:employee, organization: organization, role: 'admin')
        expect(subject).to permit(admin, entry)
      end

      it 'denies manager' do
        expect(subject).not_to permit(manager, entry)
      end

      it 'denies plain employee' do
        expect(subject).not_to permit(employee, entry)
      end
    end
  end
end
