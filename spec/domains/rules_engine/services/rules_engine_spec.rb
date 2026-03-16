# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RulesEngine do
  let(:org)      { create(:organization) }
  let(:employee) { create(:employee, organization: org) }
  let(:leave_request) { create(:leave_request, employee: employee, days_count: 7) }

  before { ActsAsTenant.current_tenant = org }
  after  { ActsAsTenant.current_tenant = nil }

  let(:context) do
    {
      'leave_type' => leave_request.leave_type,
      'days_count' => leave_request.days_count,
      'role'       => employee.role
    }
  end

  subject(:engine) { described_class.new(org) }

  context 'when rules_engine_enabled is false (default)' do
    it 'returns empty array without evaluating any rules' do
      create(:business_rule, organization: org, trigger: 'leave_request.submitted')
      results = engine.trigger('leave_request.submitted', resource: leave_request, context: context)
      expect(results).to be_empty
    end
  end

  context 'when rules_engine_enabled is true' do
    before do
      org.update!(settings: org.settings.merge('rules_engine_enabled' => true))
    end

    it 'returns empty array when no rules exist' do
      results = engine.trigger('leave_request.submitted', resource: leave_request, context: context)
      expect(results).to be_empty
    end

    context 'with a matching rule' do
      let!(:rule) do
        create(:business_rule,
          organization: org,
          trigger:      'leave_request.submitted',
          conditions:   [{ 'field' => 'days_count', 'operator' => 'gte', 'value' => 5 }],
          actions:      [{ 'type' => 'require_approval', 'role' => 'manager', 'order' => 1 }]
        )
      end

      it 'returns a matched result' do
        results = engine.trigger('leave_request.submitted', resource: leave_request, context: context)
        expect(results.first.matched).to be true
      end

      it 'creates an approval step' do
        expect {
          engine.trigger('leave_request.submitted', resource: leave_request, context: context)
        }.to change(ApprovalStep, :count).by(1)
      end

      it 'logs a rule execution' do
        expect {
          engine.trigger('leave_request.submitted', resource: leave_request, context: context)
        }.to change(RuleExecution, :count).by(1)
      end

      it 'logs result as executed' do
        engine.trigger('leave_request.submitted', resource: leave_request, context: context)
        expect(RuleExecution.last.result).to eq('executed')
      end
    end

    context 'with a non-matching rule' do
      let!(:rule) do
        create(:business_rule,
          organization: org,
          trigger:      'leave_request.submitted',
          conditions:   [{ 'field' => 'days_count', 'operator' => 'gte', 'value' => 30 }],
          actions:      [{ 'type' => 'require_approval', 'role' => 'manager', 'order' => 1 }]
        )
      end

      it 'returns a non-matched result' do
        results = engine.trigger('leave_request.submitted', resource: leave_request, context: context)
        expect(results.first.matched).to be false
      end

      it 'does not create approval steps' do
        expect {
          engine.trigger('leave_request.submitted', resource: leave_request, context: context)
        }.not_to change(ApprovalStep, :count)
      end

      it 'logs result as skipped' do
        engine.trigger('leave_request.submitted', resource: leave_request, context: context)
        expect(RuleExecution.last.result).to eq('skipped')
      end
    end

    context 'tenant isolation' do
      let(:other_org) { create(:organization) }
      let!(:other_rule) do
        ActsAsTenant.without_tenant do
          create(:business_rule,
            organization: other_org,
            trigger:      'leave_request.submitted',
            conditions:   [],
            actions:      [{ 'type' => 'block', 'reason' => 'Bloqué' }]
          )
        end
      end

      it 'does not evaluate rules from another organisation' do
        results = engine.trigger('leave_request.submitted', resource: leave_request, context: context)
        expect(results).to be_empty
      end
    end
  end
end
