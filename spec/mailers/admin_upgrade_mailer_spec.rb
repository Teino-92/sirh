# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminUpgradeMailer, type: :mailer do
  let(:organization) { create(:organization, name: 'Acme Corp') }

  describe '#upgrade_requested' do
    let(:mail) do
      described_class.upgrade_requested(
        organization,
        contact_name:    'Alice Dupont',
        contact_email:   'alice@acme.fr',
        contact_message: 'Je veux passer en SIRH'
      )
    end

    it 'sends to ADMIN_EMAIL' do
      expect(mail.to).to include(ENV.fetch('ADMIN_EMAIL', 'contact@izi-rh.com'))
    end

    it 'sets reply_to to contact email' do
      expect(mail.reply_to).to include('alice@acme.fr')
    end

    it 'includes organization name in subject' do
      expect(mail.subject).to include('Acme Corp')
    end

    it 'includes upgrade mention in subject' do
      expect(mail.subject).to include('upgrade')
    end

    it 'renders without error' do
      expect { mail.deliver_now }.not_to raise_error
    end

    context 'without contact email' do
      let(:mail) do
        described_class.upgrade_requested(organization, contact_name: 'Alice')
      end

      it 'sends without reply_to' do
        expect { mail.deliver_now }.not_to raise_error
      end
    end
  end
end
