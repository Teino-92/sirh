# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillingsController, type: :controller do
  let(:organization) { create(:organization, trial_ends_at: 30.days.from_now) }
  let(:admin)        { create(:employee, organization: organization, role: 'admin') }
  let(:manager)      { create(:employee, organization: organization, role: 'manager') }
  let(:employee)     { create(:employee, organization: organization, role: 'employee') }

  before { ActsAsTenant.current_tenant = organization }
  after  { ActsAsTenant.current_tenant = nil }

  # ─── GET /billing ──────────────────────────────────────────────────────────

  describe 'GET #show' do
    context 'as admin' do
      before { sign_in admin }

      it 'returns 200' do
        get :show
        expect(response).to have_http_status(:ok)
      end

      it 'renders without error' do
        get :show
        expect(response).not_to be_redirect
      end
    end

    context 'as manager during trial' do
      before { sign_in manager }

      it 'returns 200' do
        get :show
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as plain employee' do
      before { sign_in employee }

      it 'redirects (Pundit not authorized)' do
        get :show
        expect(response).to be_redirect
      end
    end

    context 'when not authenticated' do
      it 'redirects to sign in' do
        get :show
        expect(response).to redirect_to(new_employee_session_path)
      end
    end
  end

  # ─── POST /billing/checkout ────────────────────────────────────────────────

  describe 'POST #create_checkout' do
    before { sign_in admin }

    context 'with a valid plan' do
      let(:checkout_result) do
        CheckoutService::Result.new(true, 'https://checkout.stripe.com/test', nil)
      end

      before do
        allow_any_instance_of(CheckoutService).to receive(:call).and_return(checkout_result)
      end

      it 'redirects to Stripe checkout URL' do
        post :create_checkout, params: { plan: 'sirh_essential' }
        expect(response).to redirect_to('https://checkout.stripe.com/test')
      end
    end

    context 'with an invalid plan' do
      it 'redirects back to billing with alert' do
        post :create_checkout, params: { plan: 'invalid_plan' }
        expect(response).to redirect_to(billing_path)
        expect(flash[:alert]).to include('invalide')
      end
    end

    context 'when CheckoutService fails' do
      let(:failure_result) { CheckoutService::Result.new(false, nil, 'Stripe error') }

      before do
        allow_any_instance_of(CheckoutService).to receive(:call).and_return(failure_result)
      end

      it 'redirects back to billing with alert' do
        post :create_checkout, params: { plan: 'sirh_essential' }
        expect(response).to redirect_to(billing_path)
        expect(flash[:alert]).to include('Stripe error')
      end
    end

    context 'as manager after trial expired' do
      let(:organization) { create(:organization, trial_ends_at: 1.day.ago) }
      let(:manager)      { create(:employee, organization: organization, role: 'manager') }

      before { sign_in manager }

      it 'redirects (Pundit not authorized)' do
        post :create_checkout, params: { plan: 'sirh_essential' }
        expect(response).to be_redirect
      end
    end
  end

  # ─── GET /billing/success ──────────────────────────────────────────────────

  describe 'GET #success' do
    before { sign_in admin }

    it 'returns 200' do
      get :success
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── POST /billing/upgrade ─────────────────────────────────────────────────

  describe 'POST #upgrade' do
    before { sign_in admin }

    context 'when self-upgrade is available' do
      let(:upgrade_result) { SubscriptionUpgradeService::Result.new(true, nil) }

      before do
        allow_any_instance_of(BillingService).to receive(:can_self_upgrade?).and_return(true)
        allow_any_instance_of(SubscriptionUpgradeService).to receive(:call).and_return(upgrade_result)
      end

      it 'redirects to billing with notice' do
        post :upgrade
        expect(response).to redirect_to(billing_path)
        expect(flash[:notice]).to include('Pro')
      end
    end

    context 'when self-upgrade is not available' do
      before do
        allow_any_instance_of(BillingService).to receive(:can_self_upgrade?).and_return(false)
      end

      it 'redirects back with alert' do
        post :upgrade
        expect(response).to redirect_to(billing_path)
        expect(flash[:alert]).to be_present
      end
    end

    context 'when upgrade service fails' do
      let(:failure_result) { SubscriptionUpgradeService::Result.new(false, 'Stripe error') }

      before do
        allow_any_instance_of(BillingService).to receive(:can_self_upgrade?).and_return(true)
        allow_any_instance_of(SubscriptionUpgradeService).to receive(:call).and_return(failure_result)
      end

      it 'redirects back with error alert' do
        post :upgrade
        expect(response).to redirect_to(billing_path)
        expect(flash[:alert]).to include('Stripe error')
      end
    end
  end

  # ─── POST /billing/request_upgrade ────────────────────────────────────────

  describe 'POST #request_upgrade' do
    before { sign_in admin }

    let(:valid_contact_params) do
      {
        contact_name:    'Alice Dupont',
        contact_email:   'alice@acme.fr',
        contact_message: 'Je veux passer en SIRH'
      }
    end

    context 'when upgrade requires contact' do
      let(:success_result) { SubscriptionUpgradeService::Result.new(true, nil) }

      before do
        allow_any_instance_of(BillingService).to receive(:upgrade_requires_contact?).and_return(true)
        allow_any_instance_of(SubscriptionUpgradeService).to receive(:call).and_return(success_result)
      end

      it 'redirects to billing with notice' do
        post :request_upgrade, params: valid_contact_params
        expect(response).to redirect_to(billing_path)
        expect(flash[:notice]).to be_present
      end
    end

    context 'with missing contact name' do
      before do
        allow_any_instance_of(BillingService).to receive(:upgrade_requires_contact?).and_return(true)
      end

      it 'redirects back with alert' do
        post :request_upgrade, params: valid_contact_params.merge(contact_name: '')
        expect(response).to redirect_to(billing_path)
        expect(flash[:alert]).to be_present
      end
    end

    context 'with invalid email' do
      before do
        allow_any_instance_of(BillingService).to receive(:upgrade_requires_contact?).and_return(true)
      end

      it 'redirects back with alert' do
        post :request_upgrade, params: valid_contact_params.merge(contact_email: 'not-an-email')
        expect(response).to redirect_to(billing_path)
        expect(flash[:alert]).to include('invalide')
      end
    end

    context 'when upgrade_requires_contact? is false' do
      before do
        allow_any_instance_of(BillingService).to receive(:upgrade_requires_contact?).and_return(false)
      end

      it 'redirects back with alert' do
        post :request_upgrade, params: valid_contact_params
        expect(response).to redirect_to(billing_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  # ─── DELETE /billing/cancel ────────────────────────────────────────────────

  describe 'DELETE #cancel' do
    before { sign_in admin }

    context 'with an active cancellable subscription' do
      let!(:subscription) do
        ActsAsTenant.with_tenant(organization) do
          create(:subscription, :active,
                 organization: organization,
                 cancel_at_period_end: false,
                 commitment_end_at: nil)
        end
      end

      before do
        allow(Stripe::Subscription).to receive(:update).and_return(true)
      end

      it 'redirects to billing with notice' do
        delete :cancel
        expect(response).to redirect_to(billing_path)
        expect(flash[:notice]).to be_present
      end

      it 'calls Stripe::Subscription.update' do
        expect(Stripe::Subscription).to receive(:update)
          .with(subscription.stripe_subscription_id, cancel_at_period_end: true)
        delete :cancel
      end

      it 'sets cancel_at_period_end on the subscription' do
        delete :cancel
        expect(subscription.reload.cancel_at_period_end).to be true
      end
    end

    context 'with no active subscription' do
      it 'redirects back with alert' do
        delete :cancel
        expect(response).to redirect_to(billing_path)
        expect(flash[:alert]).to include('Aucun abonnement')
      end
    end

    context 'with subscription under commitment' do
      let!(:subscription) do
        ActsAsTenant.with_tenant(organization) do
          create(:subscription, :active, :committed, organization: organization)
        end
      end

      it 'redirects back with commitment alert' do
        delete :cancel
        expect(response).to redirect_to(billing_path)
        expect(flash[:alert]).to include('engagement')
      end
    end

    context 'when Stripe raises an error' do
      let!(:subscription) do
        ActsAsTenant.with_tenant(organization) do
          create(:subscription, :active,
                 organization: organization,
                 commitment_end_at: nil)
        end
      end

      before do
        allow(Stripe::Subscription).to receive(:update)
          .and_raise(Stripe::StripeError.new('Network error'))
      end

      it 'redirects back with Stripe error alert' do
        delete :cancel
        expect(response).to redirect_to(billing_path)
        expect(flash[:alert]).to include('Stripe')
      end
    end
  end
end
