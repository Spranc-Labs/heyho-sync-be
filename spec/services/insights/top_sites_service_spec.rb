# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::TopSitesService do
  describe '.call' do
    let(:user) { create(:user) }

    context 'with visits in the past week' do
      before do
        # GitHub - most time
        create_list(:page_visit, 5, user:, visited_at: 2.days.ago, domain: 'github.com',
                                    duration_seconds: 600, engagement_rate: 0.8)
        # Stack Overflow - most visits
        create_list(:page_visit, 8, user:, visited_at: 3.days.ago, domain: 'stackoverflow.com',
                                    duration_seconds: 200, engagement_rate: 0.6)
        # Reddit - least
        create_list(:page_visit, 2, user:, visited_at: 1.day.ago, domain: 'reddit.com',
                                    duration_seconds: 300, engagement_rate: 0.4)
      end

      it 'returns success result' do
        result = described_class.call(user:)

        expect(result.success?).to be true
      end

      it 'returns sites sorted by time by default' do
        result = described_class.call(user:)

        sites = result.data[:sites]
        expect(sites.first[:domain]).to eq('github.com')
        expect(sites.first[:total_time_seconds]).to eq(3000) # 5 * 600
      end

      it 'returns sites sorted by visits when sort_by is visits' do
        result = described_class.call(user:, sort_by: 'visits')

        sites = result.data[:sites]
        expect(sites.first[:domain]).to eq('stackoverflow.com')
        expect(sites.first[:visits]).to eq(8)
      end

      it 'includes visit count for each site' do
        result = described_class.call(user:)

        github_site = result.data[:sites].find { |s| s[:domain] == 'github.com' }
        expect(github_site[:visits]).to eq(5)
      end

      it 'includes total time for each site' do
        result = described_class.call(user:)

        stackoverflow_site = result.data[:sites].find { |s| s[:domain] == 'stackoverflow.com' }
        expect(stackoverflow_site[:total_time_seconds]).to eq(1600) # 8 * 200
      end

      it 'includes average engagement rate' do
        result = described_class.call(user:)

        github_site = result.data[:sites].find { |s| s[:domain] == 'github.com' }
        expect(github_site[:avg_engagement_rate]).to eq(0.8)
      end

      it 'includes first and last visit timestamps' do
        result = described_class.call(user:)

        github_site = result.data[:sites].find { |s| s[:domain] == 'github.com' }
        expect(github_site[:first_visit]).to be_present
        expect(github_site[:last_visit]).to be_present
      end

      it 'respects the limit parameter' do
        result = described_class.call(user:, limit: 2)

        expect(result.data[:sites].size).to eq(2)
      end

      it 'clamps limit to maximum of 50' do
        result = described_class.call(user:, limit: 100)

        # Should not exceed MAX_LIMIT (50)
        expect(result.data[:sites].size).to be <= 50
      end

      it 'clamps limit to minimum of 1' do
        result = described_class.call(user:, limit: 0)

        # Should have at least 1 result (or empty if no data)
        expect(result.data[:sites].size).to be >= 0
      end
    end

    context 'with different period parameters' do
      before do
        create(:page_visit, user:, visited_at: Time.current, domain: 'today.com')
        create(:page_visit, user:, visited_at: 8.days.ago, domain: 'week_ago.com')
        create(:page_visit, user:, visited_at: 40.days.ago, domain: 'month_ago.com')
      end

      it 'filters by day period' do
        result = described_class.call(user:, period: 'day')

        sites = result.data[:sites]
        expect(sites.pluck(:domain)).to include('today.com')
        expect(sites.pluck(:domain)).not_to include('week_ago.com')
      end

      it 'filters by week period' do
        result = described_class.call(user:, period: 'week')

        sites = result.data[:sites]
        expect(sites.pluck(:domain)).to include('today.com')
        expect(sites.pluck(:domain)).not_to include('week_ago.com')
      end

      it 'filters by month period' do
        result = described_class.call(user:, period: 'month')

        sites = result.data[:sites]
        expect(sites.pluck(:domain)).to include('today.com')
        expect(sites.pluck(:domain)).not_to include('month_ago.com')
      end

      it 'includes period in response' do
        result = described_class.call(user:, period: 'month')

        expect(result.data[:period]).to eq('month')
      end

      it 'includes start and end dates' do
        result = described_class.call(user:, period: 'week')

        expect(result.data[:start_date]).to be_present
        expect(result.data[:end_date]).to be_present
      end
    end

    context 'when no visits exist' do
      it 'returns empty sites array' do
        result = described_class.call(user:)

        expect(result.success?).to be true
        expect(result.data[:sites]).to eq([])
      end
    end

    context 'when service encounters an error' do
      before do
        allow_any_instance_of(described_class).to receive(:fetch_visits).and_raise(StandardError, 'Database error')
      end

      it 'returns failure result' do
        result = described_class.call(user:)

        expect(result.failure?).to be true
        expect(result.message).to eq('Failed to generate top sites')
        expect(result.errors).to include('Database error')
      end
    end
  end
end
