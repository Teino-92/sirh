# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OneOnOneMailer, type: :mailer do
  let(:organization) { create(:organization) }
  let(:manager)      { create(:employee, organization: organization, role: 'manager') }
  let(:employee)     { create(:employee, organization: organization, manager: manager) }
  let(:one_on_one) do
    ActsAsTenant.with_tenant(organization) do
      create(:one_on_one, organization: organization, manager: manager, employee: employee,
             scheduled_at: 3.days.from_now)
    end
  end

  describe '#scheduled' do
    let(:mail) { described_class.scheduled(one_on_one) }

    it 'sends to the employee' do
      expect(mail.to).to include(employee.email)
    end

    it 'includes manager name in subject' do
      expect(mail.subject).to include(manager.full_name)
    end

    it 'renders without error' do
      expect { mail.deliver_now }.not_to raise_error
    end
  end

  describe '#rescheduled' do
    let(:mail) { described_class.rescheduled(one_on_one) }

    it 'sends to the employee' do
      expect(mail.to).to include(employee.email)
    end

    it 'mentions replanifié in subject' do
      expect(mail.subject).to include('replanifié')
    end

    it 'renders without error' do
      expect { mail.deliver_now }.not_to raise_error
    end
  end

  describe '#cancelled' do
    let(:mail) { described_class.cancelled(one_on_one) }

    it 'sends to the employee' do
      expect(mail.to).to include(employee.email)
    end

    it 'mentions annulé in subject' do
      expect(mail.subject).to include('annulé')
    end

    it 'renders without error' do
      expect { mail.deliver_now }.not_to raise_error
    end
  end
end
