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

    # ── Magic link ─────────────────────────────────────────────────────────
    describe 'magic link' do
      # Décode le body (quoted-printable ou base64) et extrait le token brut
      def extract_token(mail)
        decoded = mail.body.parts.find { |p| p.content_type.include?('html') }&.decoded ||
                  mail.body.decoded
        match = decoded.match(%r{/super_admin/upgrade/([^"'\s<>]+)})
        match&.[](1)
      end

      it 'includes a magic link in the email body' do
        decoded = mail.body.decoded
        expect(decoded).to include('/super_admin/upgrade/')
      end

      it 'magic link contains a signed token for the correct org' do
        token = extract_token(mail)
        expect(token).to be_present

        payload = Rails.application.message_verifier('sirh_upgrade').verify(token)
        expect(payload["org_id"]).to eq(organization.id)
      end

      it 'magic link expires after 7 days' do
        token = extract_token(mail)
        expect(token).to be_present

        # Valide maintenant
        expect {
          Rails.application.message_verifier('sirh_upgrade').verify(token)
        }.not_to raise_error

        # Expiré dans 8 jours
        travel 8.days do
          expect {
            Rails.application.message_verifier('sirh_upgrade').verify(token)
          }.to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
        end
      end
    end

    context 'without contact email' do
      let(:mail) do
        described_class.upgrade_requested(organization, contact_name: 'Alice')
      end

      it 'sends without reply_to' do
        expect { mail.deliver_now }.not_to raise_error
      end

      it 'still includes the magic link' do
        body = mail.body.encoded
        expect(body).to include('/super_admin/upgrade/')
      end
    end

    context 'without any contact info' do
      let(:mail) { described_class.upgrade_requested(organization) }

      it 'renders without error' do
        expect { mail.deliver_now }.not_to raise_error
      end
    end
  end
end
