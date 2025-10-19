# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncLog do
  # Associations
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  # Validations
  describe 'validations' do
    subject(:sync_log) { build(:sync_log) }

    it { is_expected.to validate_presence_of(:synced_at) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(SyncLog::STATUSES) }

    it do
      expect(sync_log).to validate_numericality_of(:page_visits_synced)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end

    it do
      expect(sync_log).to validate_numericality_of(:tab_aggregates_synced)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end

    it do
      expect(sync_log).to validate_numericality_of(:rejected_records_count)
        .only_integer
        .is_greater_than_or_equal_to(0)
    end
  end

  # Scopes
  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:old_log) { create(:sync_log, user:, synced_at: 2.days.ago, status: 'completed') }
    let!(:new_log) { create(:sync_log, user:, synced_at: 1.day.ago, status: 'completed') }
    let!(:failed_log) { create(:sync_log, user:, synced_at: 1.hour.ago, status: 'failed') }

    describe '.recent' do
      it 'orders by synced_at descending' do
        expect(described_class.recent.to_a).to eq([failed_log, new_log, old_log])
      end
    end

    describe '.for_user' do
      it 'returns logs for specific user' do
        other_user = create(:user)
        other_log = create(:sync_log, user: other_user)

        expect(described_class.for_user(user.id)).to contain_exactly(old_log, new_log, failed_log)
        expect(described_class.for_user(other_user.id)).to contain_exactly(other_log)
      end
    end

    describe '.by_status' do
      it 'returns logs with specific status' do
        expect(described_class.by_status('completed')).to contain_exactly(old_log, new_log)
        expect(described_class.by_status('failed')).to contain_exactly(failed_log)
      end
    end

    describe '.completed' do
      it 'returns only completed logs' do
        expect(described_class.completed).to contain_exactly(old_log, new_log)
      end
    end

    describe '.failed' do
      it 'returns only failed logs' do
        expect(described_class.failed).to contain_exactly(failed_log)
      end
    end

    describe '.with_validation_errors' do
      it 'returns logs with rejected records' do
        other_user = create(:user)
        create(:sync_log, user: other_user, rejected_records_count: 0)
        dirty_log = create(:sync_log, user: other_user, rejected_records_count: 5)

        expect(described_class.for_user(other_user.id).with_validation_errors).to contain_exactly(dirty_log)
      end
    end

    describe '.clean' do
      it 'returns logs without rejected records' do
        other_user = create(:user)
        clean_log = create(:sync_log, user: other_user, rejected_records_count: 0)
        create(:sync_log, user: other_user, rejected_records_count: 5)

        expect(described_class.for_user(other_user.id).clean).to contain_exactly(clean_log)
      end
    end
  end

  # Class methods
  describe '.last_sync_for' do
    let(:user) { create(:user) }

    it 'returns most recent completed sync' do
      create(:sync_log, user:, synced_at: 2.days.ago, status: 'completed')
      latest = create(:sync_log, user:, synced_at: 1.day.ago, status: 'completed')
      create(:sync_log, user:, synced_at: 1.hour.ago, status: 'failed')

      expect(described_class.last_sync_for(user)).to eq(latest)
    end

    it 'returns nil if no completed syncs' do
      create(:sync_log, user:, status: 'failed')

      expect(described_class.last_sync_for(user)).to be_nil
    end
  end

  describe '.success_rate_for' do
    let(:user) { create(:user) }

    it 'calculates success rate' do
      create_list(:sync_log, 8, user:, status: 'completed')
      create_list(:sync_log, 2, user:, status: 'failed')

      expect(described_class.success_rate_for(user)).to eq(80.0)
    end

    it 'returns 0.0 if no syncs' do
      expect(described_class.success_rate_for(user)).to eq(0.0)
    end
  end

  # Instance methods
  describe '#total_synced' do
    it 'returns sum of page_visits and tab_aggregates' do
      log = build(:sync_log, page_visits_synced: 100, tab_aggregates_synced: 50)
      expect(log.total_synced).to eq(150)
    end
  end

  describe '#success?' do
    it 'returns true when status is completed' do
      log = build(:sync_log, status: 'completed')
      expect(log.success?).to be true
    end

    it 'returns false when status is not completed' do
      log = build(:sync_log, status: 'failed')
      expect(log.success?).to be false
    end
  end

  describe '#failure?' do
    it 'returns true when status is failed' do
      log = build(:sync_log, status: 'failed')
      expect(log.failure?).to be true
    end

    it 'returns false when status is not failed' do
      log = build(:sync_log, status: 'completed')
      expect(log.failure?).to be false
    end
  end

  describe '#mark_completed!' do
    it 'updates status to completed' do
      log = create(:sync_log, status: 'processing')
      log.mark_completed!
      expect(log.reload.status).to eq('completed')
    end
  end

  describe '#mark_failed!' do
    it 'updates status to failed and stores error messages' do
      log = create(:sync_log, status: 'processing')
      messages = ['Connection timeout', 'Invalid data']

      log.mark_failed!(messages)

      expect(log.reload.status).to eq('failed')
      expect(log.error_messages).to eq(messages)
    end

    it 'handles single error string' do
      log = create(:sync_log, status: 'processing')

      log.mark_failed!('Something went wrong')

      expect(log.reload.error_messages).to eq(['Something went wrong'])
    end
  end

  describe '#add_validation_error' do
    it 'adds validation error to the log' do
      log = create(:sync_log)

      log.add_validation_error(
        record_id: 'pv_123',
        record_type: 'page_visit',
        field: 'url',
        message: 'is invalid'
      )

      expect(log.validation_errors.size).to eq(1)
      expect(log.validation_errors.first).to include(
        'record_id' => 'pv_123',
        'record_type' => 'page_visit',
        'field' => 'url',
        'message' => 'is invalid'
      )
      expect(log.rejected_records_count).to eq(1)
    end

    it 'includes value when provided' do
      log = create(:sync_log)

      log.add_validation_error(
        record_id: 'pv_123',
        record_type: 'page_visit',
        field: 'scroll_depth',
        message: 'exceeds maximum',
        value: 150
      )

      expect(log.validation_errors.first['value']).to eq(150)
    end

    it 'includes timestamp' do
      log = create(:sync_log)

      log.add_validation_error(
        record_id: 'pv_123',
        record_type: 'page_visit',
        field: 'url',
        message: 'is invalid'
      )

      expect(log.validation_errors.first['timestamp']).to be_present
    end

    it 'increments rejected_records_count' do
      log = create(:sync_log, rejected_records_count: 5)

      log.add_validation_error(
        record_id: 'pv_123',
        record_type: 'page_visit',
        field: 'url',
        message: 'is invalid'
      )

      expect(log.rejected_records_count).to eq(6)
    end
  end

  describe '#validation_errors?' do
    it 'returns true when there are rejected records' do
      log = build(:sync_log, rejected_records_count: 5)
      expect(log.validation_errors?).to be true
    end

    it 'returns false when there are no rejected records' do
      log = build(:sync_log, rejected_records_count: 0)
      expect(log.validation_errors?).to be false
    end
  end

  describe '#data_quality_score' do
    it 'returns 100.0 when no records' do
      log = build(:sync_log, page_visits_synced: 0, tab_aggregates_synced: 0, rejected_records_count: 0)
      expect(log.data_quality_score).to eq(100.0)
    end

    it 'calculates score when all records are valid' do
      log = build(:sync_log, page_visits_synced: 100, tab_aggregates_synced: 50, rejected_records_count: 0)
      expect(log.data_quality_score).to eq(100.0)
    end

    it 'calculates score with some rejected records' do
      log = build(:sync_log, page_visits_synced: 80, tab_aggregates_synced: 0, rejected_records_count: 20)
      expect(log.data_quality_score).to eq(80.0)
    end

    it 'calculates score with multiple types of records' do
      log = build(:sync_log, page_visits_synced: 70, tab_aggregates_synced: 20, rejected_records_count: 10)
      expect(log.data_quality_score).to eq(90.0)
    end
  end

  describe '#total_records' do
    it 'returns sum of all records including rejected' do
      log = build(:sync_log, page_visits_synced: 100, tab_aggregates_synced: 50, rejected_records_count: 10)
      expect(log.total_records).to eq(160)
    end
  end
end
