# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StripeWebhooksController, type: :controller do
  let(:valid_payload)   { '{"type":"checkout.session.completed"}' }
  let(:valid_signature) { 'whsec_test_signature' }

  describe 'POST #create' do
    before do
      request.env['RAW_POST_DATA'] = valid_payload
    end

    context 'when signature header is missing' do
      it 'returns 400' do
        post :create, body: valid_payload
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when WebhookProcessor succeeds' do
      let(:success_result) { WebhookProcessor::Result.new(true, 'ok', false) }

      before do
        request.env['HTTP_STRIPE_SIGNATURE'] = valid_signature
        allow_any_instance_of(WebhookProcessor).to receive(:call).and_return(success_result)
      end

      it 'returns 200' do
        post :create, body: valid_payload
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when WebhookProcessor returns signature failure' do
      let(:sig_failure_result) { WebhookProcessor::Result.new(false, 'Invalid signature', true) }

      before do
        request.env['HTTP_STRIPE_SIGNATURE'] = valid_signature
        allow_any_instance_of(WebhookProcessor).to receive(:call).and_return(sig_failure_result)
      end

      it 'returns 400' do
        post :create, body: valid_payload
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when WebhookProcessor returns internal error' do
      let(:error_result) { WebhookProcessor::Result.new(false, 'DB error', false) }

      before do
        request.env['HTTP_STRIPE_SIGNATURE'] = valid_signature
        allow_any_instance_of(WebhookProcessor).to receive(:call).and_return(error_result)
      end

      it 'returns 500' do
        post :create, body: valid_payload
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
