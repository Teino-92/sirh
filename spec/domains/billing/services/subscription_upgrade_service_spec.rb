# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubscriptionUpgradeService do
  let(:org) { create(:organization, plan: 'sirh') }
  let(:sub) { create(:subscription, organization: org, status: 'active', plan: 'sirh_essential', stripe_subscription_id: 'sub_123') }

  let(:service) { described_class.new(organization: org, target_plan: 'sirh_pro') }

  let(:fake_price)        { double('Stripe::Price', id: 'price_pro_123') }
  let(:fake_stripe_item)  { double('Stripe::SubscriptionItem', id: 'si_abc') }
  let(:fake_stripe_sub)   { double('Stripe::Subscription', items: double(data: [fake_stripe_item])) }

  before do
    sub # ensure sub is created
    allow(Stripe::Price).to receive(:list).and_return(double(data: [fake_price]))
    allow(Stripe::Subscription).to receive(:retrieve).and_return(fake_stripe_sub)
    allow(Stripe::Subscription).to receive(:update).and_return(true)
    allow(AdminUpgradeMailer).to receive_message_chain(:upgrade_requested, :deliver_later)
  end

  describe '#call' do
    context 'upgrade sirh_essential → sirh_pro (self-service)' do
      it 'returns success' do
        result = service.call
        expect(result.success?).to be true
        expect(result.error).to be_nil
      end

      it 'calls Stripe::Subscription.update with proration' do
        service.call
        expect(Stripe::Subscription).to have_received(:update).with(
          'sub_123',
          hash_including(proration_behavior: 'always_invoice')
        )
      end

      it 'updates subscription plan to sirh_pro' do
        service.call
        expect(sub.reload.plan).to eq('sirh_pro')
      end

      it 'updates organization plan to sirh' do
        service.call
        expect(org.reload.plan).to eq('sirh')
      end

      it 'rolls back DB changes if Stripe raises' do
        allow(Stripe::Subscription).to receive(:update)
          .and_raise(Stripe::StripeError.new('network_error'))

        result = service.call
        expect(result.success?).to be false
        expect(sub.reload.plan).to eq('sirh_essential')
      end
    end

    context 'upgrade from wrong plan' do
      let(:sub) { create(:subscription, organization: org, status: 'active', plan: 'manager_os') }

      it 'returns failure when trying to upgrade to sirh_pro from manager_os' do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include('Essentiel')
      end
    end

    context 'upgrade manager_os → sirh (requires contact)' do
      let(:org) { create(:organization, plan: 'manager_os') }
      let(:sub) { create(:subscription, organization: org, status: 'active', plan: 'manager_os') }

      let(:service) do
        described_class.new(
          organization:    org,
          target_plan:     'sirh',
          contact_name:    'Jean Dupont',
          contact_email:   'jean@example.com',
          contact_message: 'Je veux upgrader'
        )
      end

      it 'returns success' do
        result = service.call
        expect(result.success?).to be true
      end

      it 'sends an admin upgrade email' do
        service.call
        expect(AdminUpgradeMailer).to have_received(:upgrade_requested)
      end

      it 'does not modify the subscription' do
        service.call
        expect(sub.reload.plan).to eq('manager_os')
      end

      it 'does not call Stripe' do
        service.call
        expect(Stripe::Subscription).not_to have_received(:update)
      end
    end

    context 'when no active subscription' do
      let(:sub) { create(:subscription, organization: org, status: 'canceled', plan: 'sirh_essential') }

      it 'returns failure' do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include('actif')
      end
    end

    context 'when no subscription at all' do
      let(:org_empty) { ActsAsTenant.without_tenant { create(:organization, plan: 'sirh') } }

      it 'returns failure without subscription' do
        result = described_class.new(organization: org_empty, target_plan: 'sirh_pro').call
        expect(result.success?).to be false
      end
    end

    context 'with an invalid target plan' do
      let(:service) { described_class.new(organization: org, target_plan: 'unknown') }

      it 'returns failure' do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include('invalide')
      end
    end
  end
end
