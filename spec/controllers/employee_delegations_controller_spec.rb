# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmployeeDelegationsController, type: :controller do
  let(:organization) { create(:organization, plan: 'sirh') }
  let(:manager)      { create(:employee, organization: organization, role: 'manager') }
  let(:hr)           { create(:employee, organization: organization, role: 'hr') }
  let(:employee)     { create(:employee, organization: organization, role: 'employee') }

  before { ActsAsTenant.current_tenant = organization }
  after  { ActsAsTenant.current_tenant = nil }

  # When Pundit denies, ApplicationController rescues and redirects with flash[:alert]
  def expect_unauthorized(response)
    expect(response).to be_redirect
    expect(flash[:alert]).to be_present
  end

  # ─── GET #index ─────────────────────────────────────────────────────────────

  describe 'GET #index' do
    context 'as manager (SIRH plan)' do
      before { sign_in manager }

      it 'returns 200' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as hr (SIRH plan)' do
      before { sign_in hr }

      it 'returns 200' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as plain employee' do
      before { sign_in employee }

      # index? only requires sirh_plan? — employees can see their received delegations
      it 'returns 200 (employee can view their delegations)' do
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'unauthenticated' do
      it 'redirects to login' do
        get :index
        expect(response).to redirect_to(new_employee_session_path)
      end
    end
  end

  # ─── GET #new ───────────────────────────────────────────────────────────────

  describe 'GET #new' do
    context 'as manager' do
      before { sign_in manager }

      it 'returns 200' do
        get :new
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as plain employee' do
      before { sign_in employee }

      it 'redirects with alert (policy denied)' do
        get :new
        expect_unauthorized(response)
      end
    end
  end

  # ─── POST #create ───────────────────────────────────────────────────────────

  describe 'POST #create' do
    let(:valid_params) do
      {
        employee_delegation: {
          delegatee_id: hr.id,
          role:         'manager',
          starts_at:    Date.current,
          ends_at:      7.days.from_now
        }
      }
    end

    context 'as manager with valid params' do
      before { sign_in manager }

      it 'creates the delegation and redirects' do
        expect {
          post :create, params: valid_params
        }.to change(EmployeeDelegation, :count).by(1)

        expect(response).to redirect_to(employee_delegations_path)
        expect(flash[:notice]).to be_present
      end

      it 'sets delegator to current_employee and active: true' do
        post :create, params: valid_params
        delegation = EmployeeDelegation.last
        expect(delegation.delegator).to eq(manager)
        expect(delegation.active).to be true
      end
    end

    context 'with invalid params (self-delegation)' do
      before { sign_in manager }

      it 're-renders new with unprocessable_entity' do
        post :create, params: {
          employee_delegation: {
            delegatee_id: manager.id,
            role:         'manager',
            starts_at:    Date.current,
            ends_at:      7.days.from_now
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'as plain employee' do
      before { sign_in employee }

      it 'redirects with alert (policy denied)' do
        post :create, params: valid_params
        expect_unauthorized(response)
      end
    end
  end

  # ─── DELETE #destroy ────────────────────────────────────────────────────────

  describe 'DELETE #destroy' do
    let!(:delegation) do
      ActsAsTenant.with_tenant(organization) do
        create(:employee_delegation,
               organization: organization,
               delegator:    manager,
               delegatee:    hr,
               role:         'manager')
      end
    end

    context 'as the delegator' do
      before { sign_in manager }

      it 'deactivates the delegation and redirects' do
        delete :destroy, params: { id: delegation.id }
        expect(delegation.reload.active).to be false
        expect(response).to redirect_to(employee_delegations_path)
        expect(flash[:notice]).to be_present
      end
    end

    context 'as admin (who is also delegatee)' do
      let(:admin) { create(:employee, organization: organization, role: 'admin') }
      let!(:admin_delegation) do
        ActsAsTenant.with_tenant(organization) do
          create(:employee_delegation,
                 organization: organization,
                 delegator:    manager,
                 delegatee:    admin,
                 role:         'manager')
        end
      end
      before { sign_in admin }

      it 'can revoke a delegation where they are a party' do
        # policy_scope returns delegations where user is delegator OR delegatee
        delete :destroy, params: { id: admin_delegation.id }
        expect(admin_delegation.reload.active).to be false
      end
    end

    context 'as a different manager (not the delegator)' do
      let(:other_manager) { create(:employee, organization: organization, role: 'manager') }
      before { sign_in other_manager }

      it 'cannot find the delegation (scoped by delegator/delegatee)' do
        # policy_scope filters to delegations where user is delegator OR delegatee.
        # other_manager is neither, so find raises RecordNotFound (404), not a policy error.
        expect {
          delete :destroy, params: { id: delegation.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
