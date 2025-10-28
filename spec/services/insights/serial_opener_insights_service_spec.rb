# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::SerialOpenerInsightsService do
  let(:user) { create(:user) }

  describe '#call' do
    context 'with valid period preset' do
      let!(:page_visits) do
        # Create serial opener pattern (multiple visits to same URL)
        (1..10).map do |i|
          create(
            :page_visit,
            user:,
            url: 'https://github.com/user/repo/pull/123',
            title: 'PR #123',
            domain: 'github.com',
            category: 'work_code_review',
            duration_seconds: 8,
            engagement_rate: 0.5,
            visited_at: i.hours.ago
          )
        end
      end

      it 'returns success with period metadata' do
        result = described_class.call(user:, period: 'week')

        expect(result.success?).to be true
        expect(result.data[:period]).to eq('week')
        expect(result.data[:date_range]).to include(:start, :end, :days)
      end

      it 'returns serial openers with enriched insights' do
        result = described_class.call(user:, period: 'week')

        expect(result.data[:serial_openers]).to be_an(Array)
        expect(result.data[:count]).to be > 0

        opener = result.data[:serial_openers].first
        expect(opener).to include(
          :url,
          :normalized_url,
          :visit_count,
          :behavior_type,
          :engagement_type,
          :inferred_purpose,
          :behavioral_insight,
          :actionable_suggestion
        )
      end

      it 'includes adaptive threshold criteria' do
        result = described_class.call(user:, period: 'week')

        expect(result.data[:criteria]).to include(
          :min_visits_per_day,
          :effective_min_visits,
          :max_total_engagement_seconds
        )
        expect(result.data[:criteria][:min_visits_per_day]).to eq(0.43)
        expect(result.data[:criteria][:effective_min_visits]).to be_within(1).of(3)
      end

      it 'calculates frequency metrics' do
        result = described_class.call(user:, period: 'week')

        opener = result.data[:serial_openers].first
        expect(opener).to include(
          :time_span_hours,
          :avg_hours_between_visits,
          :visits_per_day
        )
      end
    end

    context 'with custom date range' do
      let!(:page_visits) do
        (1..5).map do |i|
          create(
            :page_visit,
            user:,
            url: 'https://notion.so/page-abc',
            visited_at: Date.parse('2025-10-15') + i.hours,
            duration_seconds: 5
          )
        end
      end

      it 'accepts custom start_date and end_date' do
        result = described_class.call(
          user:,
          start_date: '2025-10-15',
          end_date: '2025-10-20'
        )

        expect(result.success?).to be true
        expect(result.data[:period]).to eq('custom')
        expect(result.data[:date_range][:start]).to eq('2025-10-15')
        expect(result.data[:date_range][:end]).to eq('2025-10-20')
      end

      it 'filters visits to date range' do
        # Create visit outside range
        create(
          :page_visit,
          user:,
          url: 'https://notion.so/page-abc',
          visited_at: Date.parse('2025-10-01'),
          duration_seconds: 5
        )

        result = described_class.call(
          user:,
          start_date: '2025-10-15',
          end_date: '2025-10-20'
        )

        # Should only find 5 visits, not 6
        opener = result.data[:serial_openers].first
        expect(opener[:visit_count]).to eq(5)
      end
    end

    context 'with comparison enabled' do
      let!(:current_visits) do
        (1..8).map do |i|
          create(
            :page_visit,
            user:,
            url: 'https://mail.google.com',
            visited_at: i.days.ago,
            duration_seconds: 10
          )
        end
      end

      let!(:previous_visits) do
        (8..12).map do |i|
          create(
            :page_visit,
            user:,
            url: 'https://mail.google.com',
            visited_at: i.days.ago,
            duration_seconds: 10
          )
        end
      end

      it 'includes comparison data when include_comparison=true' do
        result = described_class.call(user:, period: 'week', include_comparison: true)

        expect(result.success?).to be true
        expect(result.data[:comparison]).to be_present
      end

      it 'includes previous period metadata' do
        result = described_class.call(user:, period: 'week', include_comparison: true)

        expect(result.data[:comparison][:previous_period]).to include(
          :start,
          :end,
          :count
        )
      end

      it 'includes overall comparison stats' do
        result = described_class.call(user:, period: 'week', include_comparison: true)

        comparison = result.data[:comparison]
        expect(comparison[:overall]).to include(
          :total_serial_openers,
          :total_visits,
          :total_engagement_seconds
        )
      end

      it 'does not include comparison when include_comparison=false' do
        result = described_class.call(user:, period: 'week', include_comparison: false)

        expect(result.data[:comparison]).to be_nil
      end
    end

    context 'with no serial openers' do
      it 'returns empty array' do
        result = described_class.call(user:, period: 'week')

        expect(result.success?).to be true
        expect(result.data[:serial_openers]).to eq([])
        expect(result.data[:count]).to eq(0)
      end
    end

    context 'with URL normalization' do
      let!(:notion_visits) do
        [
          create(:page_visit, user:, url: 'https://notion.so/page-abc?v=view1',
                              visited_at: 1.hour.ago, duration_seconds: 5),
          create(:page_visit, user:, url: 'https://notion.so/page-abc?v=view2',
                              visited_at: 2.hours.ago, duration_seconds: 5),
          create(:page_visit, user:, url: 'https://notion.so/page-abc',
                              visited_at: 3.hours.ago, duration_seconds: 5)
        ]
      end

      it 'groups different URL variations as same resource' do
        result = described_class.call(user:, period: 'week')

        opener = result.data[:serial_openers].first
        expect(opener[:normalized_url]).to eq('https://notion.so/page-abc')
        expect(opener[:visit_count]).to eq(3)
        expect(opener[:url_variations_count]).to be >= 1
      end
    end

    context 'with invalid parameters' do
      it 'returns failure for invalid date range' do
        result = described_class.call(
          user:,
          start_date: '2025-10-15',
          end_date: '2025-10-01' # end before start
        )

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end

      it 'returns failure for date range exceeding 90 days' do
        result = described_class.call(
          user:,
          start_date: '2025-01-01',
          end_date: '2025-05-01'
        )

        expect(result.success?).to be false
        expect(result.message).to eq('Invalid parameters')
      end
    end

    context 'error handling' do
      it 'handles and logs unexpected errors' do
        allow(SerialOpenerDetectionService).to receive(:call).and_raise(StandardError, 'Test error')

        result = described_class.call(user:, period: 'week')

        expect(result.success?).to be false
        expect(result.message).to eq('Failed to generate insights')
      end
    end
  end
end
