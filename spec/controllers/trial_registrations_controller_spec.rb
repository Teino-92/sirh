# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TrialRegistrationsController, type: :controller do
  let(:valid_params) do
    {
      trial: {
        organization_name: 'Acme Corp',
        first_name:        'Alice',
        last_name:         'Dupont',
        email:             'alice@acme.fr',
        plan:              'sirh'
      }
    }
  end

  describe 'POST #create' do
    context 'when registration succeeds' do
      let(:employee) { build_stubbed(:employee, email: 'alice@acme.fr') }
      let(:success_result) { TrialRegistrationService::Result.new(true, employee, []) }

      before do
        allow_any_instance_of(TrialRegistrationService).to receive(:call).and_return(success_result)
      end

      it 'redirects to sign in page' do
        post :create, params: valid_params
        expect(response).to redirect_to(new_employee_session_path)
      end

      it 'sets a flash notice with the employee email' do
        post :create, params: valid_params
        expect(flash[:notice]).to include('alice@acme.fr')
      end

      it 'returns 302 status' do
        post :create, params: valid_params
        expect(response).to have_http_status(:found)
      end
    end

    context 'when registration fails' do
      let(:failure_result) { TrialRegistrationService::Result.new(false, nil, ['Email déjà utilisé']) }

      before do
        allow_any_instance_of(TrialRegistrationService).to receive(:call).and_return(failure_result)
      end

      it 'returns 422 status' do
        post :create, params: valid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not redirect' do
        post :create, params: valid_params
        expect(response).not_to be_redirect
      end
    end

    context 'with unpermitted params' do
      let(:success_result) { TrialRegistrationService::Result.new(true, build_stubbed(:employee, email: 'alice@acme.fr'), []) }

      before do
        allow_any_instance_of(TrialRegistrationService).to receive(:call).and_return(success_result)
      end

      it 'only permits allowed params — does not raise' do
        post :create, params: {
          trial: valid_params[:trial].merge(admin: true, role: 'admin')
        }
        expect(response).not_to have_http_status(:internal_server_error)
      end
    end
  end
end
