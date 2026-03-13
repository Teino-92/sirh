# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TrialRegistrationService, type: :service do
  let(:valid_params) do
    {
      organization_name: 'Acme Corp',
      first_name:        'Alice',
      last_name:         'Dupont',
      email:             'alice@acme.fr',
      plan:              'sirh'
    }
  end

  let(:faraday_connection) { instance_double(Faraday::Connection) }
  let(:faraday_response)   { instance_double(Faraday::Response) }

  before do
    allow(Faraday).to receive(:new).and_return(faraday_connection)
    allow(faraday_connection).to receive(:post).and_return(faraday_response)
    allow(faraday_response).to receive(:success?).and_return(true)
  end

  describe '#call' do
    context 'with valid sirh params' do
      it 'returns success' do
        result = described_class.new(valid_params).call
        expect(result.success?).to be true
      end

      it 'creates an organization' do
        expect { described_class.new(valid_params).call }
          .to change(Organization, :count).by(1)
      end

      it 'sets organization plan to sirh' do
        described_class.new(valid_params).call
        expect(Organization.last.plan).to eq('sirh')
      end

      it 'sets billing_model to per_employee for sirh' do
        described_class.new(valid_params).call
        expect(Organization.last.billing_model).to eq('per_employee')
      end

      it 'sets trial_ends_at to 30 days from now' do
        described_class.new(valid_params).call
        org = Organization.last
        expect(org.trial_ends_at).to be_within(1.minute).of(30.days.from_now)
      end

      it 'creates an employee with role hr for sirh' do
        result = described_class.new(valid_params).call
        expect(result.employee.role).to eq('hr')
      end

      it 'sets employee email correctly' do
        result = described_class.new(valid_params).call
        expect(result.employee.email).to eq('alice@acme.fr')
      end

      it 'downcases the email' do
        result = described_class.new(valid_params.merge(email: 'Alice@ACME.FR')).call
        expect(result.employee.email).to eq('alice@acme.fr')
      end

      it 'returns the created employee' do
        result = described_class.new(valid_params).call
        expect(result.employee).to be_a(Employee)
        expect(result.employee).to be_persisted
      end

      it 'returns empty errors' do
        result = described_class.new(valid_params).call
        expect(result.errors).to be_empty
      end

      it 'generates a reset password token for the employee' do
        result = described_class.new(valid_params).call
        expect(result.employee.reset_password_token).to be_present
      end

      it 'sends a welcome email via Resend' do
        expect(faraday_connection).to receive(:post).and_return(faraday_response)
        described_class.new(valid_params).call
      end
    end

    context 'with valid manager_os params' do
      let(:params) { valid_params.merge(plan: 'manager_os') }

      it 'returns success' do
        result = described_class.new(params).call
        expect(result.success?).to be true
      end

      it 'sets organization plan to manager_os' do
        described_class.new(params).call
        expect(Organization.last.plan).to eq('manager_os')
      end

      it 'sets billing_model to per_team for manager_os' do
        described_class.new(params).call
        expect(Organization.last.billing_model).to eq('per_team')
      end

      it 'creates an employee with role admin for manager_os (founder is admin)' do
        result = described_class.new(params).call
        expect(result.employee.role).to eq('admin')
      end
    end

    context 'with unknown plan' do
      let(:params) { valid_params.merge(plan: 'unknown_plan') }

      it 'defaults to sirh plan' do
        result = described_class.new(params).call
        expect(result.success?).to be true
        expect(Organization.last.plan).to eq('sirh')
      end
    end

    context 'with missing organization name' do
      let(:params) { valid_params.merge(organization_name: '') }

      it 'returns failure' do
        result = described_class.new(params).call
        expect(result.success?).to be false
      end

      it 'returns validation errors' do
        result = described_class.new(params).call
        expect(result.errors).not_to be_empty
      end

      it 'does not create an organization' do
        expect { described_class.new(params).call }
          .not_to change(Organization, :count)
      end

      it 'does not create an employee' do
        expect { described_class.new(params).call }
          .not_to change(Employee, :count)
      end
    end

    context 'with duplicate email' do
      before do
        org = create(:organization)
        ActsAsTenant.with_tenant(org) do
          create(:employee, organization: org, email: 'alice@acme.fr')
        end
      end

      it 'returns failure' do
        result = described_class.new(valid_params).call
        expect(result.success?).to be false
      end

      it 'returns errors' do
        result = described_class.new(valid_params).call
        expect(result.errors).not_to be_empty
      end
    end

    context 'when Resend API fails' do
      before do
        allow(faraday_response).to receive(:success?).and_return(false)
        allow(faraday_response).to receive(:status).and_return(422)
        allow(faraday_response).to receive(:body).and_return('error')
      end

      it 'returns failure' do
        result = described_class.new(valid_params).call
        expect(result.success?).to be false
      end

      it 'returns a generic error message' do
        result = described_class.new(valid_params).call
        expect(result.errors).not_to be_empty
      end

      # Note: the email is sent outside the transaction (after commit), so the
      # organization and employee are already persisted when Resend fails.
      # This is a known trade-off — the user receives an error but the account
      # exists and can be recovered via password reset.
      it 'org is persisted even when email fails (email sent outside transaction)' do
        expect { described_class.new(valid_params).call }
          .to change(Organization, :count).by(1)
      end
    end

    context 'with whitespace in params' do
      let(:params) { valid_params.merge(organization_name: '  Acme Corp  ', first_name: ' Alice ') }

      it 'strips whitespace from organization name' do
        described_class.new(params).call
        expect(Organization.last.name).to eq('Acme Corp')
      end

      it 'strips whitespace from first name' do
        result = described_class.new(params).call
        expect(result.employee.first_name).to eq('Alice')
      end
    end
  end
end
