# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RuleConditionEvaluator do
  describe '.match_all?' do
    let(:context) { { 'days_count' => 7, 'leave_type' => 'CP', 'role' => 'employee' } }

    it 'returns true when all conditions match' do
      conditions = [
        { 'field' => 'days_count', 'operator' => 'gte', 'value' => 5 },
        { 'field' => 'leave_type', 'operator' => 'eq',  'value' => 'CP' }
      ]
      expect(described_class.match_all?(conditions, context)).to be true
    end

    it 'returns false when one condition fails' do
      conditions = [
        { 'field' => 'days_count', 'operator' => 'gte', 'value' => 5 },
        { 'field' => 'leave_type', 'operator' => 'eq',  'value' => 'RTT' }
      ]
      expect(described_class.match_all?(conditions, context)).to be false
    end

    it 'returns true for empty conditions' do
      expect(described_class.match_all?([], context)).to be true
    end
  end

  describe '#match?' do
    subject(:evaluator) { described_class.new(condition, context) }

    context 'eq operator' do
      let(:condition) { { 'field' => 'leave_type', 'operator' => 'eq', 'value' => 'CP' } }
      let(:context)   { { 'leave_type' => 'CP' } }
      it { expect(evaluator.match?).to be true }
    end

    context 'neq operator' do
      let(:condition) { { 'field' => 'leave_type', 'operator' => 'neq', 'value' => 'RTT' } }
      let(:context)   { { 'leave_type' => 'CP' } }
      it { expect(evaluator.match?).to be true }

      it 'returns true when field is nil (nil != value is semantically true)' do
        cond = { 'field' => 'manager_id', 'operator' => 'neq', 'value' => 42 }
        expect(described_class.new(cond, {}).match?).to be true
      end
    end

    context 'gte operator' do
      let(:condition) { { 'field' => 'days_count', 'operator' => 'gte', 'value' => 5 } }

      it 'matches when equal' do
        expect(described_class.new(condition, { 'days_count' => 5 }).match?).to be true
      end

      it 'matches when greater' do
        expect(described_class.new(condition, { 'days_count' => 10 }).match?).to be true
      end

      it 'does not match when less' do
        expect(described_class.new(condition, { 'days_count' => 3 }).match?).to be false
      end
    end

    context 'in operator' do
      let(:condition) { { 'field' => 'leave_type', 'operator' => 'in', 'value' => ['CP', 'RTT'] } }

      it 'matches when value is in list' do
        expect(described_class.new(condition, { 'leave_type' => 'CP' }).match?).to be true
      end

      it 'does not match when value not in list' do
        expect(described_class.new(condition, { 'leave_type' => 'MALADIE' }).match?).to be false
      end
    end

    context 'between operator' do
      let(:context) { { 'days_count' => 7 } }

      it 'matches when value is within range' do
        cond = { 'field' => 'days_count', 'operator' => 'between', 'value' => [5, 10] }
        expect(described_class.new(cond, context).match?).to be true
      end

      it 'matches on boundary values' do
        cond = { 'field' => 'days_count', 'operator' => 'between', 'value' => [7, 7] }
        expect(described_class.new(cond, context).match?).to be true
      end

      it 'does not match when outside range' do
        cond = { 'field' => 'days_count', 'operator' => 'between', 'value' => [1, 5] }
        expect(described_class.new(cond, context).match?).to be false
      end
    end

    context 'present operator' do
      it 'matches when field has a value' do
        cond = { 'field' => 'comment', 'operator' => 'present' }
        expect(described_class.new(cond, { 'comment' => 'hello' }).match?).to be true
      end

      it 'does not match when field is nil' do
        cond = { 'field' => 'comment', 'operator' => 'present' }
        expect(described_class.new(cond, { 'comment' => nil }).match?).to be false
      end

      it 'does not match when field is empty string' do
        cond = { 'field' => 'comment', 'operator' => 'present' }
        expect(described_class.new(cond, { 'comment' => '' }).match?).to be false
      end

      it 'does not match when field is absent from context' do
        cond = { 'field' => 'comment', 'operator' => 'present' }
        expect(described_class.new(cond, {}).match?).to be false
      end
    end

    context 'blank operator' do
      it 'matches when field is nil' do
        cond = { 'field' => 'comment', 'operator' => 'blank' }
        expect(described_class.new(cond, { 'comment' => nil }).match?).to be true
      end

      it 'matches when field is empty string' do
        cond = { 'field' => 'comment', 'operator' => 'blank' }
        expect(described_class.new(cond, { 'comment' => '' }).match?).to be true
      end

      it 'matches when field is absent from context' do
        cond = { 'field' => 'comment', 'operator' => 'blank' }
        expect(described_class.new(cond, {}).match?).to be true
      end

      it 'does not match when field has a value' do
        cond = { 'field' => 'comment', 'operator' => 'blank' }
        expect(described_class.new(cond, { 'comment' => 'hello' }).match?).to be false
      end
    end

    context 'unknown operator' do
      let(:condition) { { 'field' => 'days_count', 'operator' => 'unknown', 'value' => 5 } }
      let(:context)   { { 'days_count' => 5 } }
      it { expect(evaluator.match?).to be false }
    end

    context 'missing field in context' do
      let(:condition) { { 'field' => 'missing_field', 'operator' => 'eq', 'value' => 'x' } }
      let(:context)   { {} }
      it { expect(evaluator.match?).to be false }
    end
  end
end
