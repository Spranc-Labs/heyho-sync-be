# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::DailySummaryService do
  describe '.call' do
    let(:user) { create(:user) }
    let(:today) { Time.zone.today }

    context 'with visits for today' do
      before do
        # Create visits at different hours
        create_list(:page_visit, 3, user:, visited_at: today.beginning_of_day + 9.hours,
                                    domain: 'github.com', duration_seconds: 300, engagement_rate: 0.8)
        create_list(:page_visit, 2, user:, visited_at: today.beginning_of_day + 14.hours,
                                    domain: 'stackoverflow.com', duration_seconds: 200, engagement_rate: 0.6)
        create(:page_visit, user:, visited_at: today.beginning_of_day + 16.hours,
                            domain: 'github.com', duration_seconds: 400, engagement_rate: 0.9)

        # Create a visit from yesterday (should not be included)
        create(:page_visit, user:, visited_at: 1.day.ago)
      end

      it 'returns success result' do
        result = described_class.call(user:, date: today)

        expect(result.success?).to be true
      end

      it 'returns correct total sites visited' do
        result = described_class.call(user:, date: today)

        expect(result.data[:total_sites_visited]).to eq(6)
      end

      it 'returns correct unique domains count' do
        result = described_class.call(user:, date: today)

        expect(result.data[:unique_domains]).to eq(2)
      end

      it 'calculates total time correctly' do
        result = described_class.call(user:, date: today)

        # (3 * 300) + (2 * 200) + 400 = 1700
        expect(result.data[:total_time_seconds]).to eq(1700)
      end

      it 'calculates average engagement rate' do
        result = described_class.call(user:, date: today)

        # (3*0.8 + 2*0.6 + 0.9) / 6 = 4.5 / 6 = 0.75
        expect(result.data[:avg_engagement_rate]).to eq(0.75)
      end

      it 'identifies top domain by time' do
        result = described_class.call(user:, date: today)

        expect(result.data[:top_domain][:domain]).to eq('github.com')
        expect(result.data[:top_domain][:visits]).to eq(4)
        expect(result.data[:top_domain][:time_seconds]).to eq(1300)
      end

      it 'includes hourly breakdown' do
        result = described_class.call(user:, date: today)

        expect(result.data[:hourly_breakdown]).to be_an(Array)
        expect(result.data[:hourly_breakdown].size).to be >= 3

        hour_9 = result.data[:hourly_breakdown].find { |h| h[:hour] == 9 }
        expect(hour_9[:visits]).to eq(3)
        expect(hour_9[:time_seconds]).to eq(900)
      end

      it 'includes correct date in response' do
        result = described_class.call(user:, date: today)

        expect(result.data[:date]).to eq(today.to_s)
      end
    end

    context 'when no visits exist for date' do
      it 'returns empty summary' do
        result = described_class.call(user:, date: today)

        expect(result.success?).to be true
        expect(result.data[:total_sites_visited]).to eq(0)
        expect(result.data[:unique_domains]).to eq(0)
        expect(result.data[:total_time_seconds]).to eq(0)
        expect(result.data[:avg_engagement_rate]).to eq(0.0)
        expect(result.data[:top_domain]).to be_nil
      end
    end

    context 'when date parameter is a string' do
      it 'parses the date correctly' do
        create(:page_visit, user:, visited_at: today.beginning_of_day + 10.hours)

        result = described_class.call(user:, date: today.to_s)

        expect(result.success?).to be true
        expect(result.data[:total_sites_visited]).to eq(1)
      end
    end

    context 'when date parameter is invalid' do
      it 'falls back to today' do
        create(:page_visit, user:, visited_at: today.beginning_of_day + 10.hours)

        result = described_class.call(user:, date: 'invalid-date')

        expect(result.success?).to be true
        expect(result.data[:total_sites_visited]).to eq(1)
      end
    end

    context 'when visits have invalid data' do
      before do
        # Create valid visits
        create_list(:page_visit, 2, user:, visited_at: today.beginning_of_day + 10.hours)

        # Create invalid visits (should be filtered by valid_data scope)
        # Use build + save(validate: false) to bypass validations
        # Note: Can't test nil URL as it has NOT NULL constraint at DB level
        invalid_visit = build(:page_visit, user:, visited_at: today.beginning_of_day + 12.hours,
                                           duration_seconds: -100, engagement_rate: 1.5) # Invalid: negative duration and invalid engagement
        invalid_visit.save(validate: false)
      end

      it 'only counts valid visits' do
        result = described_class.call(user:, date: today)

        expect(result.data[:total_sites_visited]).to eq(2)
      end
    end

    context 'when service encounters an error' do
      before do
        allow_any_instance_of(described_class).to receive(:fetch_visits).and_raise(StandardError, 'Database error')
      end

      it 'returns failure result' do
        result = described_class.call(user:, date: today)

        expect(result.failure?).to be true
        expect(result.message).to eq('Failed to generate daily summary')
        expect(result.errors).to include('Database error')
      end
    end
  end
end
