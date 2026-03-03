# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeePolicy, type: :policy do
  let(:organization)  { create(:organization) }
  let(:admin)         { create(:employee, organization: organization, role: 'admin') }
  let(:hr)            { create(:employee, organization: organization, role: 'hr') }
  let(:manager)       { create(:employee, organization: organization, role: 'manager') }
  let(:subordinate)   { create(:employee, organization: organization, manager: manager) }
  let(:peer_employee) { create(:employee, organization: organization) }

  subject { described_class }

  # edit? et update? sont limités à soi-même (hors Admin::BaseController qui restreint déjà à hr_or_admin?)
  permissions :edit?, :update? do
    it 'permits the employee on their own record' do
      expect(subject).to permit(subordinate, subordinate)
    end

    it 'denies a manager on a subordinate' do
      expect(subject).not_to permit(manager, subordinate)
    end

    it 'denies an employee on a peer' do
      expect(subject).not_to permit(peer_employee, subordinate)
    end
  end

  # Droit du travail français : confidentialité salariale stricte.
  # Seuls HR/admin et l'employé lui-même peuvent consulter un salaire.
  # Utilisé pour show, edit, update (guard salary fields).
  permissions :see_salary? do
    it 'permits admin' do
      expect(subject).to permit(admin, subordinate)
    end

    it 'permits hr' do
      expect(subject).to permit(hr, subordinate)
    end

    it 'permits the employee viewing their own salary' do
      expect(subject).to permit(subordinate, subordinate)
    end

    it 'denies a manager viewing their own subordinate salary' do
      expect(subject).not_to permit(manager, subordinate)
    end

    it 'denies a manager viewing a peer salary' do
      expect(subject).not_to permit(manager, peer_employee)
    end

    it 'denies an employee viewing a peer salary' do
      expect(subject).not_to permit(peer_employee, subordinate)
    end
  end
end
