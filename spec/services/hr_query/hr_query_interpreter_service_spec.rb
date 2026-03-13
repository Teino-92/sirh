# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HrQuery::HrQueryInterpreterService, type: :service do
  subject(:service) { described_class.new(query) }

  # Stub the Faraday connection so we never make real HTTP calls
  let(:faraday_connection) { instance_double(Faraday::Connection) }
  let(:faraday_response)   { instance_double(Faraday::Response) }

  before do
    allow(Faraday).to receive(:new).and_return(faraday_connection)
    allow(faraday_connection).to receive(:post).and_yield(faraday_response_builder).and_return(faraday_response)
    allow(Rails.application.credentials).to receive(:anthropic_api_key).and_return('sk-ant-test-key')
  end

  # Helper that simulates the Faraday block-based DSL
  let(:faraday_response_builder) do
    req = Object.new
    def req.headers; @headers ||= {}; end
    def req.body=(_); end
    req
  end

  def stub_api_success(json_tail)
    allow(faraday_response).to receive(:status).and_return(200)
    allow(faraday_response).to receive(:body).and_return(
      { "content" => [{ "type" => "text", "text" => json_tail }] }.to_json
    )
  end

  describe '#call' do
    context 'with an empty query' do
      let(:query) { '   ' }

      it 'returns failure without calling the API' do
        expect(Faraday).not_to have_received(:new)
        result = service.call
        expect(result.success).to be false
        expect(result.error).to include("vide")
      end
    end

    context 'with a valid query' do
      let(:query) { 'Employés du département Ventes' }

      let(:valid_json_tail) do
        '"employee":{"department":"Ventes","role":null,"contract_type":null,"active_only":true,' \
        '"cadre":null,"job_title_contains":null,"tenure_months_min":null,"tenure_months_max":null,' \
        '"start_date_from":null,"start_date_to":null},' \
        '"leave":{"leave_type":null,"days_used_min":null,"days_used_max":null,"period_year":null,"status":null},' \
        '"evaluation":{"score_min":null,"score_max":null,"period_year":null,"status":null},' \
        '"onboarding":{"status":null,"integration_score_min":null,"integration_score_max":null},' \
        '"output":{"columns":["name","department"],"include_salary":false}}'
      end

      before { stub_api_success(valid_json_tail) }

      it 'returns success with parsed filters' do
        result = service.call
        expect(result.success).to be true
        expect(result.filters).to be_a(Hash)
        expect(result.filters["version"]).to eq("1")
        expect(result.filters.dig("employee", "department")).to eq("Ventes")
      end

      it 'returns nil error on success' do
        result = service.call
        expect(result.error).to be_nil
      end
    end

    context 'when the API returns a non-200 status' do
      let(:query) { 'Employés CDI' }

      before do
        allow(faraday_response).to receive(:status).and_return(500)
        allow(faraday_response).to receive(:body).and_return('Internal Server Error')
      end

      it 'returns failure with an error message' do
        result = service.call
        expect(result.success).to be false
        expect(result.error).to include("500")
      end
    end

    context 'when the API returns invalid JSON' do
      let(:query) { 'Employés stage' }

      before do
        allow(faraday_response).to receive(:status).and_return(200)
        allow(faraday_response).to receive(:body).and_return('not json at all')
      end

      it 'returns failure' do
        result = service.call
        expect(result.success).to be false
        expect(result.error).to be_present
      end
    end

    context 'when the JSON lacks the expected version field' do
      let(:query) { 'Managers cadres' }

      # Even though our prefill starts with {"version":"1", simulate a wrong version
      let(:wrong_version_tail) do
        '"employee":{},"leave":{},"evaluation":{},"onboarding":{},"output":{"columns":[]}}'
          .then { |tail| tail }
      end

      before do
        # Simulate a response where the prefill trick is bypassed somehow
        allow(faraday_response).to receive(:status).and_return(200)
        allow(faraday_response).to receive(:body).and_return(
          { "content" => [{ "type" => "text", "text" => wrong_version_tail }] }.to_json
        )
        # Override the prefill concatenation to simulate version "2"
        stub_const("HrQuery::HrQueryInterpreterService::PREFILL", '{"version":"2",')
      end

      it 'returns failure due to version mismatch' do
        result = service.call
        expect(result.success).to be false
        expect(result.error).to include("version")
      end
    end

    context 'when a timeout occurs' do
      let(:query) { 'Tous les employés' }

      before do
        allow(faraday_connection).to receive(:post).and_raise(Faraday::TimeoutError)
      end

      it 'returns failure with a friendly timeout message' do
        result = service.call
        expect(result.success).to be false
        expect(result.error).to include("Délai")
      end
    end

    context 'when the credentials key is missing' do
      let(:query) { 'Employés RTT' }

      before do
        allow(Rails.application.credentials).to receive(:anthropic_api_key).and_return(nil)
        stub_const('ENV', ENV.to_h.merge('ANTHROPIC_API_KEY' => nil))
      end

      it 'returns failure with a configuration error' do
        result = service.call
        expect(result.success).to be false
        expect(result.error).to include("Clé API")
      end
    end
  end
end
