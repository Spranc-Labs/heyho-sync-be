# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::WeeklySummaryService do
  describe '.call' do
    let(:user) { create(:user) }
    let(:week_start) { Time.zone.today.beginning_of_week(:monday) }
    let(:week_end) { week_start + 6.days }

    context 'with visits for current week' do
      before do
        # Monday visits
        create_list(:page_visit, 3, user:, visited_at: week_start.beginning_of_day + 10.hours,
                                    domain: 'github.com', duration_seconds: 300)
        # Wednesday visits
        create_list(:page_visit, 2, user:, visited_at: week_start + 2.days + 14.hours,
                                    domain: 'stackoverflow.com', duration_seconds: 200)
        # Friday visits
        create(:page_visit, user:, visited_at: week_start + 4.days + 9.hours,
                            domain: 'github.com', duration_seconds: 400)

        # Create visit from previous week (should not be included)
        create(:page_visit, user:, visited_at: week_start - 8.days)
      end

      it 'returns success result' do
        result = described_class.call(user:)

        expect(result.success?).to be true
      end

      it 'returns correct week label' do
        result = described_class.call(user:)

        expected_week = "#{week_start.year}-W#{week_start.cweek.to_s.rjust(2, "0")}"
        expect(result.data[:week]).to eq(expected_week)
      end

      it 'returns correct start and end dates' do
        result = described_class.call(user:)

        expect(result.data[:start_date]).to eq(week_start.to_s)
        expect(result.data[:end_date]).to eq(week_end.to_s)
      end

      it 'returns correct total sites visited' do
        result = described_class.call(user:)

        expect(result.data[:total_sites_visited]).to eq(6)
      end

      it 'returns correct unique domains count' do
        result = described_class.call(user:)

        expect(result.data[:unique_domains]).to eq(2)
      end

      it 'calculates total time correctly' do
        result = described_class.call(user:)

        # (3 * 300) + (2 * 200) + 400 = 1700
        expect(result.data[:total_time_seconds]).to eq(1700)
      end

      it 'includes daily breakdown' do
        result = described_class.call(user:)

        expect(result.data[:daily_breakdown]).to be_an(Array)

        monday_data = result.data[:daily_breakdown].find { |d| d[:date] == week_start.to_s }
        expect(monday_data[:visits]).to eq(3)
        expect(monday_data[:time_seconds]).to eq(900)
      end

      it 'includes top domains' do
        result = described_class.call(user:)

        expect(result.data[:top_domains]).to be_an(Array)
        expect(result.data[:top_domains].size).to be <= 10

        top_domain = result.data[:top_domains].first
        expect(top_domain[:domain]).to eq('github.com')
        expect(top_domain[:visits]).to eq(4)
        expect(top_domain[:time_seconds]).to eq(1300)
      end
    end

    context 'when week parameter is provided in ISO format' do
      let(:specific_week) { '2025-W42' }

      it 'parses the week correctly' do
        # Create visits for week 42 of 2025
        week_42_start = Date.commercial(2025, 42, 1)
        create(:page_visit, user:, visited_at: week_42_start.beginning_of_day + 10.hours)

        result = described_class.call(user:, week: specific_week)

        expect(result.success?).to be true
        expect(result.data[:week]).to eq(specific_week)
        expect(result.data[:total_sites_visited]).to eq(1)
      end
    end

    context 'when week parameter is invalid' do
      it 'falls back to current week' do
        create(:page_visit, user:, visited_at: week_start.beginning_of_day + 10.hours)

        result = described_class.call(user:, week: 'invalid-week')

        expect(result.success?).to be true
        expect(result.data[:total_sites_visited]).to eq(1)
      end
    end

    context 'when no visits exist for week' do
      it 'returns empty summary' do
        result = described_class.call(user:)

        expect(result.success?).to be true
        expect(result.data[:total_sites_visited]).to eq(0)
        expect(result.data[:unique_domains]).to eq(0)
        expect(result.data[:total_time_seconds]).to eq(0)
        expect(result.data[:daily_breakdown]).to eq([])
        expect(result.data[:top_domains]).to eq([])
      end
    end

    context 'when service encounters an error' do
      before do
        allow_any_instance_of(described_class).to receive(:fetch_visits).and_raise(StandardError, 'Database error')
      end

      it 'returns failure result' do
        result = described_class.call(user:)

        expect(result.failure?).to be true
        expect(result.message).to eq('Failed to generate weekly summary')
        expect(result.errors).to include('Database error')
      end
    end
  end
end
