require 'rails_helper'

RSpec.describe Training, type: :model do
  let(:organization) { create(:organization) }

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should have_many(:training_assignments).dependent(:destroy) }
    it { should have_many(:employees).through(:training_assignments) }
  end

  describe 'validations' do
    subject { build(:training, organization: organization) }

    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:training_type) }
    it { should validate_length_of(:title).is_at_most(255) }

    it 'validates duration_estimate is positive when present' do
      training = build(:training, organization: organization, duration_estimate: -1)
      expect(training).not_to be_valid
      expect(training.errors[:duration_estimate]).to be_present
    end

    it 'allows nil duration_estimate' do
      training = build(:training, organization: organization, duration_estimate: nil)
      expect(training).to be_valid
    end

    it 'defines training_type enum values' do
      expect(Training.training_types.keys).to contain_exactly(
        'internal', 'external', 'certification', 'e_learning', 'mentoring'
      )
    end
  end

  describe 'scopes' do
    before do
      ActsAsTenant.with_tenant(organization) do
        create(:training, organization: organization, training_type: :internal)
        create(:training, organization: organization, training_type: :external)
        create(:training, :archived, organization: organization, training_type: :certification)
      end
    end

    describe '.active' do
      it 'returns trainings without archived_at' do
        ActsAsTenant.with_tenant(organization) do
          expect(Training.active.count).to eq(2)
        end
      end
    end

    describe '.archived' do
      it 'returns only archived trainings' do
        ActsAsTenant.with_tenant(organization) do
          expect(Training.archived.count).to eq(1)
        end
      end
    end

    describe '.by_type' do
      it 'filters by training type' do
        ActsAsTenant.with_tenant(organization) do
          expect(Training.by_type(:internal).count).to eq(1)
          expect(Training.by_type(:external).count).to eq(1)
        end
      end
    end
  end

  describe 'instance methods' do
    let(:training) { create(:training, organization: organization) }

    describe '#archive!' do
      it 'sets archived_at' do
        expect { training.archive! }.to change { training.reload.archived_at }.from(nil)
      end

      it 'is idempotent — does nothing if already archived' do
        training.archive!
        original_archived_at = training.reload.archived_at

        travel 1.hour do
          training.archive!
        end

        expect(training.reload.archived_at).to eq(original_archived_at)
      end
    end

    describe '#unarchive!' do
      it 'clears archived_at' do
        training.update_columns(archived_at: 1.day.ago)
        expect { training.unarchive! }.to change { training.reload.archived_at }.to(nil)
      end

      it 'is idempotent — does nothing if not archived' do
        expect { training.unarchive! }.not_to raise_error
        expect(training.reload.archived_at).to be_nil
      end
    end

    describe '#archived?' do
      it 'returns false when not archived' do
        expect(training.archived?).to be false
      end

      it 'returns true when archived' do
        training.update_columns(archived_at: 1.day.ago)
        expect(training.archived?).to be true
      end
    end
  end

  describe 'multi-tenancy' do
    it 'scopes trainings to organization' do
      org1 = create(:organization)
      org2 = create(:organization)

      ActsAsTenant.with_tenant(org1) { create(:training, organization: org1) }
      ActsAsTenant.with_tenant(org2) { create(:training, organization: org2) }

      ActsAsTenant.with_tenant(org1) { expect(Training.count).to eq(1) }
      ActsAsTenant.with_tenant(org2) { expect(Training.count).to eq(1) }
    end
  end
end
