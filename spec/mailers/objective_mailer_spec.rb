# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObjectiveMailer, type: :mailer do
  let(:organization) { create(:organization) }
  let(:manager)      { create(:employee, organization: organization, role: 'manager') }
  let(:employee)     { create(:employee, organization: organization, manager: manager) }
  let(:objective) do
    ActsAsTenant.with_tenant(organization) do
      create(:objective,
             organization: organization,
             owner: employee,
             manager: manager,
             created_by: manager)
    end
  end

  describe '#assigned' do
    let(:mail) { described_class.assigned(objective) }

    it 'sends to the employee' do
      expect(mail.to).to include(employee.email)
    end

    it 'includes the objective title in subject' do
      expect(mail.subject).to include(objective.title)
    end

    it 'renders without error' do
      expect { mail.deliver_now }.not_to raise_error
    end

    it 'is added to deliveries' do
      expect { mail.deliver_now }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
