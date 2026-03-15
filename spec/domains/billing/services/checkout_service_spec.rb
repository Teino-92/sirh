# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckoutService do
  let(:org) { create(:organization, plan: 'sirh', trial_ends_at: 30.days.from_now) }

  let(:service) do
    described_class.new(
      organization: org,
      plan:         'sirh_essential',
      success_url:  'https://izi-rh.com/billing/success',
      cancel_url:   'https://izi-rh.com/billing'
    )
  end

  let(:fake_price)    { double('Stripe::Price', id: 'price_123') }
  let(:fake_customer) { double('Stripe::Customer', id: 'cus_abc') }
  let(:fake_session)  { double('Stripe::Checkout::Session', url: 'https://checkout.stripe.com/pay/cs_test_123') }

  before do
    # Resolve price via env var — avoids Stripe::Price.list call
    stub_const('ENV', ENV.to_h.merge('STRIPE_PRICE_SIRH_ESSENTIAL' => 'price_123'))
    allow(Stripe::Customer).to receive(:create).and_return(fake_customer)
    allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_session)
  end

  describe '#call' do
    context 'with a valid plan and no existing subscription' do
      it 'returns success with a checkout URL' do
        result = service.call
        expect(result.success?).to be true
        expect(result.checkout_url).to eq('https://checkout.stripe.com/pay/cs_test_123')
        expect(result.error).to be_nil
      end

      it 'creates a Stripe customer' do
        service.call
        expect(Stripe::Customer).to have_received(:create).with(
          hash_including(name: org.name, metadata: { organization_id: org.id })
        )
      end

      it 'creates a Subscription record with status incomplete' do
        expect { service.call }.to change(Subscription, :count).by(1)
        expect(Subscription.last.status).to eq('incomplete')
        expect(Subscription.last.plan).to eq('sirh_essential')
      end

      it 'passes trial_end to Stripe when trial is active' do
        service.call
        expect(Stripe::Checkout::Session).to have_received(:create).with(
          hash_including(
            subscription_data: hash_including(trial_end: org.trial_ends_at.to_i)
          )
        )
      end
    end

    context 'when org already has a Stripe customer' do
      before do
        create(:subscription, organization: org, stripe_customer_id: 'cus_existing', status: 'incomplete')
      end

      it 'reuses the existing customer ID' do
        service.call
        expect(Stripe::Customer).not_to have_received(:create)
        expect(Stripe::Checkout::Session).to have_received(:create).with(
          hash_including(customer: 'cus_existing')
        )
      end
    end

    context 'with an unknown plan' do
      let(:service) do
        described_class.new(
          organization: org,
          plan:         'unknown_plan',
          success_url:  'https://izi-rh.com/billing/success',
          cancel_url:   'https://izi-rh.com/billing'
        )
      end

      it 'returns failure' do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include('inconnu')
      end
    end

    context 'when trial is expired' do
      before { org.update!(trial_ends_at: 2.days.ago) }

      it 'does not set trial_end on the Stripe session' do
        service.call
        expect(Stripe::Checkout::Session).to have_received(:create).with(
          hash_including(
            subscription_data: hash_excluding(:trial_end)
          )
        )
      end
    end

    context 'when Stripe raises an error' do
      before do
        allow(Stripe::Checkout::Session).to receive(:create)
          .and_raise(Stripe::StripeError.new('card_declined'))
      end

      it 'returns failure with error message' do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include('card_declined')
      end

      it 'does not raise' do
        expect { service.call }.not_to raise_error
      end
    end

    context 'tenant isolation' do
      let(:org_b) { ActsAsTenant.without_tenant { create(:organization) } }

      it 'creates the Subscription scoped to the correct organization' do
        service.call
        sub = Subscription.last
        expect(sub.organization_id).to eq(org.id)
        expect(sub.organization_id).not_to eq(org_b.id)
      end
    end
  end
end
