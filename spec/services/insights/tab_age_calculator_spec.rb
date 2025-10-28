# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::TabAgeCalculator do
  describe '.calculate' do
    let(:user) { create(:user) }
    let(:url) { 'https://example.com/article' }
    let(:domain) { 'example.com' }
    let(:title) { 'Test Article' }

    context 'with single visit' do
      let(:visit) do
        create(:page_visit,
               user:,
               url:,
               domain:,
               title:,
               visited_at: 3.days.ago,
               duration_seconds: 1800,
               active_duration_seconds: 360,
               engagement_rate: 0.2,
               metadata: {})
      end

      it 'calculates correct tab metadata' do
        result = described_class.calculate([visit])

        expect(result[:url]).to eq(url)
        expect(result[:title]).to eq(title)
        expect(result[:domain]).to eq(domain)
        expect(result[:visit_count]).to eq(1)
        expect(result[:is_single_visit]).to be true
      end

      it 'calculates tab age correctly' do
        result = described_class.calculate([visit])

        expect(result[:tab_age_days]).to be_within(0.1).of(3.0)
        expect(result[:days_since_last_activity]).to be_within(0.1).of(3.0)
      end

      it 'calculates duration metrics' do
        result = described_class.calculate([visit])

        expect(result[:total_duration_seconds]).to eq(1800)
        expect(result[:total_engagement_seconds]).to eq(360)
        expect(result[:average_engagement_rate]).to eq(0.2)
      end

      it 'detects tab is not likely still open for old visit' do
        result = described_class.calculate([visit])

        expect(result[:is_likely_still_open]).to be false
      end
    end

    context 'with multiple visits to same URL' do
      let(:visits) do
        [
          create(:page_visit, user:, url:, domain:, title:, visited_at: 5.days.ago,
                              duration_seconds: 1200, engagement_rate: 0.1),
          create(:page_visit, user:, url:, domain:, title:, visited_at: 3.days.ago,
                              duration_seconds: 1800, engagement_rate: 0.2),
          create(:page_visit, user:, url:, domain:, title:, visited_at: 1.day.ago,
                              duration_seconds: 900, engagement_rate: 0.15)
        ]
      end

      it 'calculates correct visit count' do
        result = described_class.calculate(visits)

        expect(result[:visit_count]).to eq(3)
        expect(result[:is_single_visit]).to be false
      end

      it 'uses first visit for tab age' do
        result = described_class.calculate(visits)

        expect(result[:first_visited_at]).to eq(visits.first.visited_at)
        expect(result[:tab_age_days]).to be_within(0.1).of(5.0)
      end

      it 'uses most recent visit for last activity' do
        result = described_class.calculate(visits)

        expect(result[:last_visited_at]).to eq(visits.last.visited_at)
        expect(result[:days_since_last_activity]).to be_within(0.1).of(1.0)
      end

      it 'sums duration and engagement across visits' do
        result = described_class.calculate(visits)

        expect(result[:total_duration_seconds]).to eq(1200 + 1800 + 900)
        expect(result[:average_engagement_rate]).to be_within(0.01).of((0.1 + 0.2 + 0.15) / 3)
      end
    end

    context 'with recent visit (likely still open)' do
      let(:visit) do
        create(:page_visit,
               user:,
               url:,
               domain:,
               title:,
               visited_at: 2.hours.ago,
               duration_seconds: 3600, # 1 hour duration
               engagement_rate: 0.1)
      end

      it 'detects tab is likely still open' do
        result = described_class.calculate([visit])

        expect(result[:is_likely_still_open]).to be true
      end
    end

    context 'with pinned tab metadata' do
      let(:visit) do
        create(:page_visit,
               user:,
               url:,
               domain:,
               title:,
               visited_at: 1.day.ago,
               metadata: { pinned: true })
      end

      it 'detects pinned status from metadata' do
        result = described_class.calculate([visit])

        expect(result[:is_pinned]).to be true
      end
    end

    context 'with null/missing values' do
      let(:visit) do
        create(:page_visit,
               user:,
               url:,
               domain:,
               title:,
               visited_at: 1.day.ago,
               duration_seconds: nil,
               engagement_rate: nil)
      end

      it 'handles null duration gracefully' do
        result = described_class.calculate([visit])

        expect(result[:total_duration_seconds]).to eq(0)
        expect(result[:is_likely_still_open]).to be false
      end

      it 'handles null engagement_rate gracefully' do
        result = described_class.calculate([visit])

        expect(result[:average_engagement_rate]).to eq(0.0)
      end
    end

    context 'with empty visits array' do
      it 'returns nil' do
        result = described_class.calculate([])

        expect(result).to be_nil
      end
    end

    context 'with TabAggregate closure data' do
      let(:visit) do
        create(:page_visit,
               user:,
               url:,
               domain:,
               title:,
               visited_at: 7.days.ago,
               duration_seconds: 1800,
               active_duration_seconds: 360,
               engagement_rate: 0.2)
      end

      let(:tab_aggregate) do
        create(:tab_aggregate,
               page_visit: visit,
               closed_at: 5.days.ago,
               total_time_seconds: 166,
               active_time_seconds: 60,
               scroll_depth_percent: 25.0)
      end

      before do
        tab_aggregate # Create the tab aggregate
      end

      it 'includes tab lifecycle status' do
        result = described_class.calculate([visit])

        expect(result[:tab_status]).to eq(:closed)
        expect(result[:closed_at]).to be_within(1.second).of(5.days.ago)
        expect(result[:actual_tab_duration_seconds]).to eq(166)
      end

      it 'calculates tab age from first visit to closure (not current time)' do
        result = described_class.calculate([visit])

        # Tab was open from 7 days ago to 5 days ago = 2 days
        expect(result[:tab_age_days]).to be_within(0.1).of(2.0)
      end

      it 'calculates days since last activity from closure time' do
        result = described_class.calculate([visit])

        # Days since closure (5 days ago)
        expect(result[:days_since_last_activity]).to be_within(0.1).of(5.0)
      end

      it 'marks tab as not likely still open when closed_at is present' do
        result = described_class.calculate([visit])

        expect(result[:is_likely_still_open]).to be false
      end
    end

    context 'without TabAggregate closure data (unknown status)' do
      let(:visit) do
        create(:page_visit,
               user:,
               url:,
               domain:,
               title:,
               visited_at: 7.days.ago,
               duration_seconds: 1800,
               active_duration_seconds: 360,
               engagement_rate: 0.2)
      end

      it 'marks tab status as unknown when no TabAggregate exists' do
        result = described_class.calculate([visit])

        expect(result[:tab_status]).to eq(:unknown)
        expect(result[:closed_at]).to be_nil
        expect(result[:actual_tab_duration_seconds]).to be_nil
      end

      it 'calculates tab age from first visit to current time when status unknown' do
        result = described_class.calculate([visit])

        # Tab age calculated from visit to now (7 days)
        expect(result[:tab_age_days]).to be_within(0.1).of(7.0)
      end

      it 'uses heuristic for likely_still_open when status unknown' do
        result = described_class.calculate([visit])

        # Old visit with no recent activity should be false
        expect(result[:is_likely_still_open]).to be false
      end
    end

    context 'with TabAggregate but missing closed_at (edge case)' do
      let(:visit) do
        create(:page_visit,
               user:,
               url:,
               domain:,
               title:,
               visited_at: 2.hours.ago,
               duration_seconds: 600,
               engagement_rate: 0.5)
      end

      # NOTE: In practice, TabAggregate requires closed_at, but testing edge case
      # where data might be incomplete

      it 'treats as unknown status if closed_at is nil' do
        result = described_class.calculate([visit])

        expect(result[:tab_status]).to eq(:unknown)
      end
    end
  end
end
