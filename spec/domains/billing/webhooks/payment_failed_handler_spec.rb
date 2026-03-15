# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentFailedHandler do
  let(:org)      { create(:organization, plan: 'sirh') }
  let(:admin)    { create(:employee, organization: org, role: 'admin') }
  let(:sub)      { create(:subscription, organization: org, status: 'active', stripe_subscription_id: 'sub_123') }
  let(:handler)  { described_class.new }

  let(:invoice) do
    double('Stripe::Invoice',
      parent: double(subscription_details: double(subscription: 'sub_123'))
    )
  end

  let(:event) { double('Stripe::Event', data: double(object: invoice)) }

  before do
    sub
    admin
    allow(BillingMailer).to receive_message_chain(:payment_failed, :deliver_later)
  end

  describe '#call' do
    it 'sets subscription status to past_due' do
      handler.call(event)
      expect(sub.reload.status).to eq('past_due')
    end

    it 'updates last_webhook_at' do
      freeze_time do
        handler.call(event)
        expect(sub.reload.last_webhook_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'sends payment_failed email to org admin' do
      handler.call(event)
      expect(BillingMailer).to have_received(:payment_failed).with(org, admin)
    end

    context 'when no stripe_subscription_id in event' do
      let(:invoice) { double('Stripe::Invoice', parent: double(subscription_details: double(subscription: nil))) }

      it 'returns early without updating anything' do
        expect { handler.call(event) }.not_to change { sub.reload.status }
      end
    end

    context 'when invoice parent is nil' do
      let(:invoice) { double('Stripe::Invoice', parent: nil) }

      it 'returns early without raising' do
        expect { handler.call(event) }.not_to raise_error
      end
    end

    context 'when no subscription found for stripe_sub_id' do
      let(:invoice) do
        double('Stripe::Invoice',
          parent: double(subscription_details: double(subscription: 'sub_unknown'))
        )
      end

      it 'returns early without raising' do
        expect { handler.call(event) }.not_to raise_error
      end

      it 'does not send email' do
        handler.call(event)
        expect(BillingMailer).not_to have_received(:payment_failed)
      end
    end

    context 'when no admin employee found' do
      before { admin.update!(role: 'employee') }

      it 'does not send email' do
        handler.call(event)
        expect(BillingMailer).not_to have_received(:payment_failed)
      end

      it 'still marks subscription as past_due' do
        handler.call(event)
        expect(sub.reload.status).to eq('past_due')
      end
    end

    context 'tenant isolation' do
      let(:org_b) { ActsAsTenant.without_tenant { create(:organization) } }
      let(:sub_b) { ActsAsTenant.without_tenant { create(:subscription, organization: org_b, status: 'active', stripe_subscription_id: 'sub_other') } }

      it 'does not affect subscriptions from other orgs' do
        sub_b
        handler.call(event)
        expect(sub_b.reload.status).to eq('active')
      end
    end
  end
end
