# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::DateRangeHelper do
  # Create a dummy class that includes the module
  let(:dummy_class) do
    Class.new do
      include Insights::DateRangeHelper
    end
  end

  let(:helper) { dummy_class.new }

  describe '#parse_date_range' do
    context 'with period presets' do
      it 'returns today range for period=today' do
        range = helper.parse_date_range(period: 'today')

        expect(range[:period]).to eq('today')
        expect(range[:is_custom]).to be false
        expect(range[:start].to_date).to eq(Time.current.to_date)
        expect(range[:end].to_date).to eq(Time.current.to_date)
      end

      it 'returns week range for period=week' do
        range = helper.parse_date_range(period: 'week')

        expect(range[:period]).to eq('week')
        expect(range[:is_custom]).to be false
        expect(range[:start]).to be <= Time.current
        expect(range[:end]).to be >= Time.current
      end

      it 'returns month range for period=month' do
        range = helper.parse_date_range(period: 'month')

        expect(range[:period]).to eq('month')
        expect(range[:is_custom]).to be false
        expect(range[:start]).to be <= 30.days.ago
      end

      it 'defaults to week for invalid period' do
        range = helper.parse_date_range(period: 'invalid')

        expect(range[:period]).to eq('week')
      end

      it 'defaults to week for nil period' do
        range = helper.parse_date_range(period: nil)

        expect(range[:period]).to eq('week')
      end
    end

    context 'with custom date range' do
      it 'parses valid date strings' do
        range = helper.parse_date_range(start_date: '2025-10-01', end_date: '2025-10-15')

        expect(range[:period]).to eq('custom')
        expect(range[:is_custom]).to be true
        expect(range[:start].to_date).to eq(Date.parse('2025-10-01'))
        expect(range[:end].to_date).to eq(Date.parse('2025-10-15'))
      end

      it 'accepts Date objects' do
        start = Date.parse('2025-10-01')
        finish = Date.parse('2025-10-15')
        range = helper.parse_date_range(start_date: start, end_date: finish)

        expect(range[:start].to_date).to eq(start)
        expect(range[:end].to_date).to eq(finish)
      end

      it 'raises error if start_date is after end_date' do
        expect do
          helper.parse_date_range(start_date: '2025-10-15', end_date: '2025-10-01')
        end.to raise_error(ArgumentError, /start_date must be before end_date/)
      end

      it 'raises error if date range exceeds 90 days' do
        expect do
          helper.parse_date_range(start_date: '2025-01-01', end_date: '2025-05-01')
        end.to raise_error(ArgumentError, /Date range cannot exceed 90 days/)
      end

      it 'raises error for invalid date format' do
        expect do
          helper.parse_date_range(start_date: 'invalid', end_date: '2025-10-15')
        end.to raise_error(ArgumentError, /Failed to parse date/)
      end
    end

    context 'with precedence' do
      it 'prioritizes custom range over period preset' do
        range = helper.parse_date_range(
          period: 'week',
          start_date: '2025-10-01',
          end_date: '2025-10-15'
        )

        expect(range[:period]).to eq('custom')
        expect(range[:is_custom]).to be true
      end
    end
  end

  describe '#previous_period_range' do
    it 'returns previous period with same duration' do
      current = helper.parse_date_range(period: 'week')
      previous = helper.previous_period_range(current)

      duration_current = current[:end] - current[:start]
      duration_previous = previous[:end] - previous[:start]

      expect(duration_previous).to be_within(1).of(duration_current)
      expect(previous[:end]).to be < current[:start]
    end

    it 'returns previous period for custom range' do
      current = helper.parse_date_range(start_date: '2025-10-15', end_date: '2025-10-20')
      previous = helper.previous_period_range(current)

      expect(previous[:start].to_date).to eq(Date.parse('2025-10-09'))
      expect(previous[:end].to_date).to eq(Date.parse('2025-10-14'))
    end

    it 'maintains is_custom flag' do
      current = helper.parse_date_range(start_date: '2025-10-15', end_date: '2025-10-20')
      previous = helper.previous_period_range(current)

      expect(previous[:is_custom]).to be true
    end
  end

  describe '#days_in_range' do
    it 'calculates days for week period' do
      range = helper.parse_date_range(period: 'week')
      days = helper.days_in_range(range)

      expect(days).to be_within(0.1).of(7.0)
    end

    it 'calculates days for custom range' do
      range = helper.parse_date_range(start_date: '2025-10-01', end_date: '2025-10-15')
      days = helper.days_in_range(range)

      expect(days).to be_within(0.1).of(15.0)
    end

    it 'calculates days for today period' do
      range = helper.parse_date_range(period: 'today')
      days = helper.days_in_range(range)

      expect(days).to be_within(0.1).of(1.0)
    end
  end
end
