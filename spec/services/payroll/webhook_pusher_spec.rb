# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payroll::WebhookPusher do
  let(:org) { build(:organization) }
  let(:pusher) { described_class.new(org) }
  let(:payload) { { period: '2026-01', employees: [] } }

  before do
    org.settings['payroll_webhook_url']    = 'https://silae.example.com/webhook'
    org.settings['payroll_webhook_secret'] = 'secret123'
    allow(Resolv).to receive(:getaddress).with('silae.example.com').and_return('1.2.3.4')
  end

  describe '#push' do
    context 'with a successful 200 response' do
      it 'returns without raising' do
        stub_request(:post, 'https://silae.example.com/webhook')
          .to_return(status: 200, body: '{}')
        expect { pusher.push(payload) }.not_to raise_error
      end

      it 'sends Authorization header when secret is configured' do
        stub = stub_request(:post, 'https://silae.example.com/webhook')
          .with(headers: { 'Authorization' => 'Bearer secret123' })
          .to_return(status: 200)
        pusher.push(payload)
        expect(stub).to have_been_requested
      end
    end

    context 'with a non-2xx response' do
      it 'raises StandardError' do
        stub_request(:post, 'https://silae.example.com/webhook')
          .to_return(status: 503, body: 'Service Unavailable')
        expect { pusher.push(payload) }.to raise_error(StandardError, /503/)
      end
    end

    context 'when no webhook URL is configured' do
      it 'raises ArgumentError' do
        org.settings.delete('payroll_webhook_url')
        expect { pusher.push(payload) }.to raise_error(ArgumentError, /No payroll_webhook_url/)
      end
    end
  end
end
