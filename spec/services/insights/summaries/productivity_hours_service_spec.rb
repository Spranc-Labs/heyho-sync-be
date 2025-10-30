# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::Summaries::ProductivityHoursService do
  describe '.call' do
    let(:user) { create(:user) }

    context 'with visits across different hours and days' do
      before do
        # High productivity hour (14:00 / 2 PM)
        create_list(:page_visit, 5, user:, visited_at: 2.days.ago.change(hour: 14),
                                    engagement_rate: 0.9, duration_seconds: 600)

        # Low productivity hour (12:00 / noon)
        create_list(:page_visit, 3, user:, visited_at: 3.days.ago.change(hour: 12),
                                    engagement_rate: 0.3, duration_seconds: 300)

        # Medium productivity hour (10:00 / 10 AM)
        create_list(:page_visit, 4, user:, visited_at: 1.day.ago.change(hour: 10),
                                    engagement_rate: 0.6, duration_seconds: 450)

        # Visits on different days of week
        # Monday - use different hour to avoid conflicts with hour 10 tests
        create_list(:page_visit, 3, user:, visited_at: Time.zone.today.beginning_of_week(:monday) + 9.hours,
                                    engagement_rate: 0.7, duration_seconds: 180)
        # Friday - use different hour to avoid conflicts with hour 14 tests
        create_list(:page_visit, 2, user:, visited_at: Time.zone.today.beginning_of_week(:monday) + 4.days + 13.hours,
                                    engagement_rate: 0.5, duration_seconds: 150)
      end

      it 'returns success result' do
        result = described_class.call(user:)

        expect(result.success?).to be true
      end

      it 'identifies most productive hour' do
        result = described_class.call(user:)

        expect(result.data[:most_productive_hour]).to eq(14)
      end

      it 'identifies least productive hour' do
        result = described_class.call(user:)

        expect(result.data[:least_productive_hour]).to eq(12)
      end

      it 'includes hourly statistics' do
        result = described_class.call(user:)

        expect(result.data[:hourly_stats]).to be_an(Array)
        expect(result.data[:hourly_stats]).not_to be_empty
      end

      it 'includes engagement rate in hourly stats' do
        result = described_class.call(user:)

        hour_14_stats = result.data[:hourly_stats].find { |h| h[:hour] == 14 }
        expect(hour_14_stats).to be_present
        expect(hour_14_stats[:avg_engagement]).to eq(0.9)
      end

      it 'includes total time in hourly stats' do
        result = described_class.call(user:)

        hour_14_stats = result.data[:hourly_stats].find { |h| h[:hour] == 14 }
        expect(hour_14_stats[:total_time_seconds]).to eq(3000) # 5 * 600
      end

      it 'includes visit count in hourly stats' do
        result = described_class.call(user:)

        hour_14_stats = result.data[:hourly_stats].find { |h| h[:hour] == 14 }
        expect(hour_14_stats[:visit_count]).to eq(5)
      end

      it 'includes day of week statistics' do
        result = described_class.call(user:)

        expect(result.data[:day_of_week_stats]).to be_an(Array)
        expect(result.data[:day_of_week_stats]).not_to be_empty
      end

      it 'includes day names in day stats' do
        result = described_class.call(user:)

        day_names = result.data[:day_of_week_stats].pluck(:day)
        # Verify we have day names (the actual days depend on when test runs)
        expect(day_names).not_to be_empty
        expect(day_names).to all(be_a(String))
      end

      it 'includes engagement rate in day stats' do
        result = described_class.call(user:)

        monday_stats = result.data[:day_of_week_stats].find { |d| d[:day] == 'Monday' }
        expect(monday_stats).to be_present
        expect(monday_stats[:avg_engagement]).to be_a(Float)
      end

      it 'includes period in response' do
        result = described_class.call(user:, period: 'week')

        expect(result.data[:period]).to eq('week')
      end
    end

    context 'with different period parameters' do
      before do
        # Recent visit (within week)
        create(:page_visit, user:, visited_at: 2.days.ago.change(hour: 10), engagement_rate: 0.8)

        # Old visit (beyond week, within month)
        create(:page_visit, user:, visited_at: 15.days.ago.change(hour: 14), engagement_rate: 0.7)

        # Very old visit (beyond month)
        create(:page_visit, user:, visited_at: 40.days.ago.change(hour: 16), engagement_rate: 0.6)
      end

      it 'filters by week period' do
        result = described_class.call(user:, period: 'week')

        hours = result.data[:hourly_stats].pluck(:hour)
        expect(hours).to include(10)
        expect(hours).not_to include(14, 16)
      end

      it 'filters by month period' do
        result = described_class.call(user:, period: 'month')

        hours = result.data[:hourly_stats].pluck(:hour)
        expect(hours).to include(10, 14)
        expect(hours).not_to include(16)
      end

      it 'defaults to week period' do
        result = described_class.call(user:)

        expect(result.data[:period]).to eq('week')
      end
    end

    context 'when no visits exist' do
      it 'returns empty hourly and day stats' do
        result = described_class.call(user:)

        expect(result.success?).to be true
        expect(result.data[:hourly_stats]).to eq([])
        expect(result.data[:day_of_week_stats]).to eq([])
        expect(result.data[:most_productive_hour]).to be_nil
        expect(result.data[:least_productive_hour]).to be_nil
      end
    end

    context 'when all visits have same engagement rate' do
      before do
        create_list(:page_visit, 3, user:, visited_at: 1.day.ago.change(hour: 10), engagement_rate: 0.5)
        create_list(:page_visit, 3, user:, visited_at: 2.days.ago.change(hour: 14), engagement_rate: 0.5)
      end

      it 'handles equal productivity hours' do
        result = described_class.call(user:)

        expect(result.success?).to be true
        expect(result.data[:most_productive_hour]).to be_present
        expect(result.data[:least_productive_hour]).to be_present
      end
    end

    context 'when service encounters an error' do
      before do
        allow_any_instance_of(described_class).to receive(:fetch_visits).and_raise(ActiveRecord::StatementInvalid, 'Database error')
      end

      it 'returns failure result' do
        result = described_class.call(user:)

        expect(result.failure?).to be true
        expect(result.message).to eq('Database query failed')
        expect(result.errors).to include('Database error')
      end
    end

    context 'with edge case period parameters' do
      before do
        create(:page_visit, user:, visited_at: 2.days.ago.change(hour: 14), engagement_rate: 0.8)
      end

      it 'defaults to week period for invalid period value' do
        result = described_class.call(user:, period: 'invalid')

        expect(result.success?).to be true
        expect(result.data[:period]).to eq('week')
      end

      it 'defaults to week period for nil period value' do
        result = described_class.call(user:, period: nil)

        expect(result.success?).to be true
        expect(result.data[:period]).to eq('week')
      end

      it 'accepts valid period: week' do
        result = described_class.call(user:, period: 'week')

        expect(result.success?).to be true
        expect(result.data[:period]).to eq('week')
      end

      it 'accepts valid period: month' do
        result = described_class.call(user:, period: 'month')

        expect(result.success?).to be true
        expect(result.data[:period]).to eq('month')
      end
    end

    context 'with null/zero duration visits' do
      before do
        # Hour 10: mix of null, zero, and valid durations
        create(:page_visit, user:, visited_at: 1.day.ago.change(hour: 10),
                            duration_seconds: nil, engagement_rate: 0.8)
        create(:page_visit, user:, visited_at: 1.day.ago.change(hour: 10),
                            duration_seconds: 0, engagement_rate: 0.9)
        create(:page_visit, user:, visited_at: 1.day.ago.change(hour: 10),
                            duration_seconds: 100, engagement_rate: 0.7)
      end

      it 'handles null duration in hourly stats by using 0' do
        result = described_class.call(user:)

        expect(result.success?).to be true
        hour_10_stats = result.data[:hourly_stats].find { |h| h[:hour] == 10 }
        expect(hour_10_stats[:total_time_seconds]).to eq(100) # Only the valid duration
      end

      it 'calculates weighted engagement correctly with null durations' do
        result = described_class.call(user:)

        expect(result.success?).to be true
        hour_10_stats = result.data[:hourly_stats].find { |h| h[:hour] == 10 }
        # Should be 0.7 (only the 100-second visit counts in weighting)
        expect(hour_10_stats[:avg_engagement]).to be_a(Float)
        expect(hour_10_stats[:avg_engagement]).to eq(0.7)
      end

      it 'includes all visits in visit_count regardless of null duration' do
        result = described_class.call(user:)

        hour_10_stats = result.data[:hourly_stats].find { |h| h[:hour] == 10 }
        expect(hour_10_stats[:visit_count]).to eq(3)
      end
    end

    context 'with all null durations' do
      before do
        create(:page_visit, user:, visited_at: 1.day.ago.change(hour: 10),
                            duration_seconds: nil, engagement_rate: 0.8)
        create(:page_visit, user:, visited_at: 1.day.ago.change(hour: 10),
                            duration_seconds: nil, engagement_rate: 0.9)
      end

      it 'returns 0 for total_time_seconds when all durations are null' do
        result = described_class.call(user:)

        expect(result.success?).to be true
        hour_10_stats = result.data[:hourly_stats].find { |h| h[:hour] == 10 }
        expect(hour_10_stats[:total_time_seconds]).to eq(0)
      end

      it 'returns 0 for weighted engagement when all durations are null' do
        result = described_class.call(user:)

        expect(result.success?).to be true
        hour_10_stats = result.data[:hourly_stats].find { |h| h[:hour] == 10 }
        expect(hour_10_stats[:avg_engagement]).to eq(0.0)
      end
    end
  end
end
