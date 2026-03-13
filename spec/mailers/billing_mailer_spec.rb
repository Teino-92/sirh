# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillingMailer, type: :mailer do
  let(:organization) { create(:organization, name: 'Acme Corp') }
  let(:employee)     { create(:employee, organization: organization, email: 'alice@acme.fr') }

  describe '#payment_failed' do
    let(:mail) { described_class.payment_failed(organization, employee) }

    it 'sends to the employee email' do
      expect(mail.to).to include('alice@acme.fr')
    end

    it 'includes échec de paiement in subject' do
      expect(mail.subject).to include('Échec de paiement')
    end

    it 'renders without error' do
      expect { mail.deliver_now }.not_to raise_error
    end

    it 'is added to deliveries in test mode' do
      expect { mail.deliver_now }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end
