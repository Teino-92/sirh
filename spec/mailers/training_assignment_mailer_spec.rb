# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TrainingAssignmentMailer, type: :mailer do
  let(:organization) { create(:organization) }
  let(:manager)      { create(:employee, organization: organization, role: 'manager') }
  let(:employee)     { create(:employee, organization: organization, manager: manager) }
  let(:training)     { create(:training, organization: organization) }
  let(:assignment) do
    ActsAsTenant.with_tenant(organization) do
      create(:training_assignment,
             training: training,
             employee: employee,
             assigned_by: manager)
    end
  end

  describe '#assigned' do
    let(:mail) { described_class.assigned(assignment) }

    it 'sends to the employee' do
      expect(mail.to).to include(employee.email)
    end

    it 'includes the training title in subject' do
      expect(mail.subject).to include(training.title)
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
