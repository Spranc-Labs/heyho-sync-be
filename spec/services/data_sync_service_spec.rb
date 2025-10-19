# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSyncService, type: :service do
  let(:user) { create(:user) }
  let(:page_visits) do
    [
      {
        'id' => 'pv_1',
        'url' => 'https://example.com',
        'title' => 'Example',
        'visited_at' => Time.current.iso8601
      }
    ]
  end
  let(:tab_aggregates) { [] }
  let(:client_info) do
    {
      user_agent: 'Mozilla/5.0',
      browser_extension_version: '1.0.0'
    }
  end

  describe '.sync' do
    context 'with valid data' do
      it 'creates a sync log' do
        expect do
          described_class.sync(user:, page_visits:, tab_aggregates:, client_info:)
        end.to change(SyncLog, :count).by(1)
      end

      it 'marks sync log as completed' do
        described_class.sync(user:, page_visits:, tab_aggregates:, client_info:)

        sync_log = SyncLog.last
        expect(sync_log.status).to eq('completed')
        expect(sync_log.page_visits_synced).to eq(1)
        expect(sync_log.tab_aggregates_synced).to eq(0)
      end

      it 'stores client info in sync log' do
        described_class.sync(user:, page_visits:, tab_aggregates:, client_info:)

        sync_log = SyncLog.last
        expect(sync_log.client_info['user_agent']).to eq('Mozilla/5.0')
        expect(sync_log.client_info['browser_extension_version']).to eq('1.0.0')
      end

      it 'returns success result' do
        result = described_class.sync(user:, page_visits:, tab_aggregates:, client_info:)

        expect(result).to be_success
        expect(result.data[:page_visits_synced]).to eq(1)
      end
    end

    context 'when sync fails' do
      it 'marks sync log as failed' do
        allow_any_instance_of(described_class).to receive(:save_batch).and_raise(StandardError, 'DB error')

        described_class.sync(user:, page_visits:, tab_aggregates:, client_info:)

        sync_log = SyncLog.last
        expect(sync_log.status).to eq('failed')
        expect(sync_log.errors).to include('DB error')
      end

      it 'returns failure result' do
        allow_any_instance_of(described_class).to receive(:save_batch).and_raise(StandardError, 'DB error')

        result = described_class.sync(user:, page_visits:, tab_aggregates:, client_info:)

        expect(result).not_to be_success
        expect(result.message).to eq('Data sync failed')
      end
    end

    context 'batch size limits' do
      it 'rejects batch exceeding MAX_BATCH_SIZE' do
        large_batch = Array.new(1001) do |i|
          {
            'id' => "pv_#{i}",
            'url' => "https://example.com/#{i}",
            'title' => "Page #{i}",
            'visited_at' => Time.current.iso8601
          }
        end

        result = described_class.sync(user:, page_visits: large_batch, tab_aggregates:, client_info:)

        expect(result).not_to be_success
        expect(result.message).to include('Batch size exceeded')
        expect(result.message).to include('Maximum 1000')
      end

      it 'accepts batch at MAX_BATCH_SIZE limit' do
        batch = Array.new(1000) do |i|
          {
            'id' => "pv_#{i}",
            'url' => "https://example.com/#{i}",
            'title' => "Page #{i}",
            'visited_at' => Time.current.iso8601
          }
        end

        result = described_class.sync(user:, page_visits: batch, tab_aggregates:, client_info:)

        expect(result).to be_success
      end
    end

    context 'without user' do
      it 'returns failure result' do
        result = described_class.sync(user: nil, page_visits:, tab_aggregates:, client_info:)

        expect(result).not_to be_success
        expect(result.message).to eq('User is required')
      end
    end
  end

  describe 'conflict resolution' do
    let(:service) { described_class.new(user:, page_visits: [], tab_aggregates: []) }

    describe '#resolve_conflict' do
      context 'with single version' do
        it 'returns the version as-is' do
          versions = [{ 'id' => '1', 'title' => 'Test' }]
          result = service.send(:resolve_conflict, versions, 'visited_at')

          expect(result).to eq(versions.first)
        end
      end

      context 'with multiple versions' do
        it 'prefers most recent version' do
          versions = [
            { 'id' => '1', 'title' => 'Old', 'visited_at' => '2024-01-01' },
            { 'id' => '1', 'title' => 'New', 'visited_at' => '2024-01-02' }
          ]
          result = service.send(:resolve_conflict, versions, 'visited_at')

          expect(result['title']).to eq('New')
          expect(result['visited_at']).to eq('2024-01-02')
        end

        it 'merges non-nil values from older versions' do
          versions = [
            { 'id' => '1', 'title' => 'Title', 'visited_at' => '2024-01-01', 'domain' => nil },
            { 'id' => '1', 'title' => nil, 'visited_at' => '2024-01-02', 'domain' => 'example.com' }
          ]
          result = service.send(:resolve_conflict, versions, 'visited_at')

          expect(result['title']).to be_nil # Most recent is nil
          expect(result['domain']).to eq('example.com') # Merged from older
          expect(result['visited_at']).to eq('2024-01-02') # Most recent
        end

        it 'prefers higher duration values' do
          versions = [
            { 'id' => '1', 'duration_seconds' => 100, 'visited_at' => '2024-01-01' },
            { 'id' => '1', 'duration_seconds' => 50, 'visited_at' => '2024-01-02' }
          ]
          result = service.send(:resolve_conflict, versions, 'visited_at')

          expect(result['duration_seconds']).to eq(100) # Higher value wins
        end

        it 'prefers higher scroll depth' do
          versions = [
            { 'id' => '1', 'scroll_depth_percent' => 50, 'closed_at' => '2024-01-01' },
            { 'id' => '1', 'scroll_depth_percent' => 75, 'closed_at' => '2024-01-02' }
          ]
          result = service.send(:resolve_conflict, versions, 'closed_at')

          expect(result['scroll_depth_percent']).to eq(75) # Higher value wins
        end
      end
    end

    describe '#merge_version_into_base' do
      it 'fills nil values in base with non-nil values from version' do
        base = { 'title' => nil, 'url' => 'https://example.com' }
        version = { 'title' => 'Example', 'url' => 'https://other.com' }

        service.send(:merge_version_into_base, base, version)

        expect(base['title']).to eq('Example')
        expect(base['url']).to eq('https://example.com') # Not overwritten
      end

      it 'uses max for duration fields' do
        base = { 'duration_seconds' => 100, 'active_duration_seconds' => 50 }
        version = { 'duration_seconds' => 150, 'active_duration_seconds' => 30 }

        service.send(:merge_version_into_base, base, version)

        expect(base['duration_seconds']).to eq(150)
        expect(base['active_duration_seconds']).to eq(50)
      end

      it 'ignores nil values in version' do
        base = { 'title' => 'Original' }
        version = { 'title' => nil }

        service.send(:merge_version_into_base, base, version)

        expect(base['title']).to eq('Original')
      end
    end
  end

  describe 'deduplication' do
    let(:service) { described_class.new(user:, page_visits: [], tab_aggregates: []) }

    it 'removes duplicates by id' do
      records = [
        { 'id' => '1', 'title' => 'First', 'visited_at' => '2024-01-01' },
        { 'id' => '1', 'title' => 'Second', 'visited_at' => '2024-01-02' },
        { 'id' => '2', 'title' => 'Unique', 'visited_at' => '2024-01-01' }
      ]

      result = service.send(:deduplicate_by_id, records, sort_by: 'visited_at')

      expect(result.size).to eq(2)
      expect(result.map { |r| r['id'] }).to contain_exactly('1', '2')
    end

    it 'keeps most recent version by default' do
      records = [
        { 'id' => '1', 'title' => 'Old', 'visited_at' => '2024-01-01' },
        { 'id' => '1', 'title' => 'New', 'visited_at' => '2024-01-02' }
      ]

      result = service.send(:deduplicate_by_id, records, sort_by: 'visited_at')

      expect(result.first['title']).to eq('New')
    end
  end
end
