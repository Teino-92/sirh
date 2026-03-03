# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PayrollWebhookJob, type: :job do
  let(:org) { create(:organization) }
  let(:hr)  { create(:employee, organization: org, role: 'hr') }
  let(:period) { Date.new(2026, 1, 1) }

  before do
    # Stub DNS so the SSRF validator accepts silae.example.com in test
    allow(Resolv).to receive(:getaddress).with('silae.example.com').and_return('1.2.3.4')
    ActsAsTenant.current_tenant = org
    create(:payroll_period, organization: org, locked_by: hr, period: period)
    org.settings['payroll_webhook_url']    = 'https://silae.example.com/webhook'
    org.settings['payroll_webhook_secret'] = 'secret123'
    org.save!
  end

  after { ActsAsTenant.current_tenant = nil }

  describe '#perform' do
    context 'when webhook URL is configured and period is locked' do
      it 'calls WebhookPusher#push' do
        pusher = instance_double(Payroll::WebhookPusher, push: true)
        allow(Payroll::WebhookPusher).to receive(:new).with(org).and_return(pusher)
        allow(Payroll::PayrollWebhookSerializer).to receive(:new).and_return(
          instance_double(Payroll::PayrollWebhookSerializer, as_json: { period: '2026-01' })
        )
        described_class.new.perform(org.id, period.to_s)
        expect(pusher).to have_received(:push)
      end

      it 'creates a success PaperTrail version' do
        allow_any_instance_of(Payroll::WebhookPusher).to receive(:push).and_return(true)
        allow_any_instance_of(Payroll::PayrollWebhookSerializer).to receive(:as_json).and_return({})
        expect {
          described_class.new.perform(org.id, period.to_s)
        }.to change(PaperTrail::Version, :count).by(1)
        v = PaperTrail::Version.last
        expect(v.event).to eq('payroll_webhook_push')
        meta = JSON.parse(v.object_changes)
        expect(meta['status']).to eq('success')
        expect(meta['period']).to eq('2026-01')
      end
    end

    context 'when the period is NOT locked' do
      it 'discards silently without pushing' do
        ActsAsTenant.with_tenant(org) { PayrollPeriod.destroy_all }
        expect(Payroll::WebhookPusher).not_to receive(:new)
        described_class.new.perform(org.id, period.to_s)
      end
    end

    context 'when no webhook URL is configured' do
      it 'discards silently without pushing' do
        org.settings.delete('payroll_webhook_url')
        org.save!(validate: false)
        expect(Payroll::WebhookPusher).not_to receive(:new)
        described_class.new.perform(org.id, period.to_s)
      end
    end

    context 'when WebhookPusher raises' do
      it 'logs a failure version and re-raises' do
        allow_any_instance_of(Payroll::WebhookPusher).to receive(:push)
          .and_raise(StandardError, 'timeout')
        allow_any_instance_of(Payroll::PayrollWebhookSerializer).to receive(:as_json).and_return({})
        expect {
          described_class.new.perform(org.id, period.to_s)
        }.to raise_error(StandardError, 'timeout')
        v = PaperTrail::Version.last
        expect(v&.event).to eq('payroll_webhook_push')
        meta = JSON.parse(v.object_changes)
        expect(meta['status']).to eq('failure')
        expect(meta['error']).to include('timeout')
      end
    end

    context 'when organization does not exist' do
      it 'discards silently' do
        expect { described_class.new.perform(0, period.to_s) }.not_to raise_error
      end
    end

    context 'tenant isolation' do
      it 'does not include employees from another organization in the payload' do
        # Create org_b and emp_b outside the current tenant context so acts_as_tenant
        # does not auto-assign org_b's employee to org.
        org_b  = ActsAsTenant.without_tenant { create(:organization) }
        emp_b  = ActsAsTenant.without_tenant { create(:employee, organization: org_b, role: 'employee') }

        captured_payload = nil
        allow_any_instance_of(Payroll::WebhookPusher).to receive(:push) { |_, p| captured_payload = p }
        allow_any_instance_of(Payroll::PayrollWebhookSerializer).to receive(:as_json).and_call_original

        # Stub PayrollCalculatorService to avoid full calculation in this test
        allow_any_instance_of(Payroll::PayrollCalculatorService).to receive(:call).and_return({})

        described_class.new.perform(org.id, period.to_s)

        employee_ids = Array(captured_payload&.dig(:employees)).map { |e| e[:id] }
        expect(employee_ids).not_to include(emp_b.id)
      end
    end

    context 'when ArgumentError is raised (e.g. URL removed mid-flight)' do
      it 'is declared as discard_on to prevent retries' do
        # discard_on only fires through the job runner, not direct .perform calls.
        # Verify the declaration is present on the job class.
        discarded = described_class.rescue_handlers.any? do |exception_class, _|
          exception_class == 'ArgumentError'
        end
        expect(discarded).to be true
      end
    end
  end
end
