# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::AdaptiveThresholdCalculator do
  describe 'threshold scaling' do
    context 'for 7-day period (baseline)' do
      let(:calculator) { described_class.new(days_in_period: 7) }

      it 'returns baseline compulsive threshold' do
        expect(calculator.min_visits_for_behavior(:compulsive)).to eq(50)
      end

      it 'returns baseline frequent threshold' do
        expect(calculator.min_visits_for_behavior(:frequent)).to eq(20)
      end

      it 'returns baseline regular threshold' do
        expect(calculator.min_visits_for_behavior(:regular)).to eq(10)
      end

      it 'returns baseline serial opener minimum visits' do
        expect(calculator.min_serial_opener_visits).to eq(3)
      end

      it 'returns baseline serial opener max engagement' do
        expect(calculator.max_serial_opener_engagement_seconds).to eq(300) # 5 minutes
      end
    end

    context 'for 1-day period' do
      let(:calculator) { described_class.new(days_in_period: 1) }

      it 'scales compulsive threshold down' do
        # 50 * (1/7) = ~7, but rounds to 7
        expect(calculator.min_visits_for_behavior(:compulsive)).to be_between(5, 10)
      end

      it 'scales frequent threshold down' do
        expect(calculator.min_visits_for_behavior(:frequent)).to be_between(2, 5)
      end

      it 'ensures minimum visits is at least 2' do
        expect(calculator.min_serial_opener_visits).to be >= 2
      end
    end

    context 'for 30-day period' do
      let(:calculator) { described_class.new(days_in_period: 30) }

      it 'scales compulsive threshold up' do
        # 50 * (30/7) = ~214
        expect(calculator.min_visits_for_behavior(:compulsive)).to be > 200
      end

      it 'scales frequent threshold up' do
        # 20 * (30/7) = ~86
        expect(calculator.min_visits_for_behavior(:frequent)).to be > 80
      end
    end
  end

  describe '#classify_behavior_by_visits' do
    let(:calculator) { described_class.new(days_in_period: 7) }

    it 'classifies as compulsive for high visit count' do
      result = calculator.classify_behavior_by_visits(60)
      expect(result).to eq(:compulsive_checking)
    end

    it 'classifies as frequent for moderate visit count' do
      result = calculator.classify_behavior_by_visits(25)
      expect(result).to eq(:frequent_monitoring)
    end

    it 'classifies as regular for low-moderate visit count' do
      result = calculator.classify_behavior_by_visits(12)
      expect(result).to eq(:regular_reference)
    end

    it 'classifies as periodic for very low visit count' do
      result = calculator.classify_behavior_by_visits(5)
      expect(result).to eq(:periodic_revisit)
    end

    it 'handles edge case at threshold boundary' do
      threshold = calculator.min_visits_for_behavior(:compulsive)
      result = calculator.classify_behavior_by_visits(threshold)
      expect(result).to eq(:compulsive_checking)
    end
  end

  describe '#classify_behavior_by_frequency' do
    let(:calculator) { described_class.new(days_in_period: 7) }

    it 'classifies as compulsive for very frequent checks (< 30min)' do
      result = calculator.classify_behavior_by_frequency(0.3)
      expect(result).to eq(:compulsive_checking)
    end

    it 'classifies as frequent for hourly checks' do
      result = calculator.classify_behavior_by_frequency(1.5)
      expect(result).to eq(:frequent_monitoring)
    end

    it 'classifies as regular for checks every few hours' do
      result = calculator.classify_behavior_by_frequency(4.0)
      expect(result).to eq(:regular_reference)
    end

    it 'classifies as periodic for infrequent checks' do
      result = calculator.classify_behavior_by_frequency(10.0)
      expect(result).to eq(:periodic_revisit)
    end

    it 'handles nil avg_hours_between' do
      result = calculator.classify_behavior_by_frequency(nil)
      expect(result).to eq(:periodic_revisit)
    end

    it 'handles zero avg_hours_between' do
      result = calculator.classify_behavior_by_frequency(0)
      expect(result).to eq(:periodic_revisit)
    end
  end

  describe '#classify_engagement_type' do
    let(:calculator) { described_class.new(days_in_period: 7) }

    it 'classifies as quick_glance for very brief visits' do
      result = calculator.classify_engagement_type(3)
      expect(result).to eq(:quick_glance)
    end

    it 'classifies as brief_check for short visits' do
      result = calculator.classify_engagement_type(10)
      expect(result).to eq(:brief_check)
    end

    it 'classifies as scan for moderate visits' do
      result = calculator.classify_engagement_type(30)
      expect(result).to eq(:scan)
    end

    it 'classifies as shallow_work for longer visits' do
      result = calculator.classify_engagement_type(90)
      expect(result).to eq(:shallow_work)
    end

    it 'handles nil avg_seconds' do
      result = calculator.classify_engagement_type(nil)
      expect(result).to eq(:quick_glance)
    end

    it 'handles zero avg_seconds' do
      result = calculator.classify_engagement_type(0)
      expect(result).to eq(:quick_glance)
    end

    it 'handles edge case at threshold boundary' do
      result = calculator.classify_engagement_type(15)
      expect(result).to eq(:scan)
    end
  end

  describe '#min_visits_per_day_threshold' do
    let(:calculator) { described_class.new(days_in_period: 7) }

    it 'returns constant 0.43 for all periods' do
      expect(calculator.min_visits_per_day_threshold).to eq(0.43)
    end

    it 'is equivalent to 3 visits per week' do
      # 0.43 visits/day * 7 days = 3.01 visits
      expect(calculator.min_visits_per_day_threshold * 7).to be_within(0.1).of(3.0)
    end
  end

  describe '#qualifies_as_serial_opener?' do
    context 'for 7-day period' do
      let(:calculator) { described_class.new(days_in_period: 7) }

      it 'qualifies with 3 visits in a week' do
        expect(calculator.qualifies_as_serial_opener?(3, 7)).to be true
      end

      it 'qualifies with 4 visits in a week' do
        expect(calculator.qualifies_as_serial_opener?(4, 7)).to be true
      end

      it 'does not qualify with 2 visits in a week' do
        expect(calculator.qualifies_as_serial_opener?(2, 7)).to be false
      end
    end

    context 'for 30-day period' do
      let(:calculator) { described_class.new(days_in_period: 30) }

      it 'qualifies with 13 visits in a month (0.43/day)' do
        expect(calculator.qualifies_as_serial_opener?(13, 30)).to be true
      end

      it 'does not qualify with 10 visits in a month (0.33/day)' do
        expect(calculator.qualifies_as_serial_opener?(10, 30)).to be false
      end

      it 'qualifies with 15 visits in a month (0.5/day)' do
        expect(calculator.qualifies_as_serial_opener?(15, 30)).to be true
      end
    end

    context 'for 1-day period' do
      let(:calculator) { described_class.new(days_in_period: 1) }

      it 'qualifies with 1 visit in a day (1.0/day)' do
        expect(calculator.qualifies_as_serial_opener?(1, 1)).to be true
      end

      it 'qualifies with 2 visits in a day (2.0/day)' do
        expect(calculator.qualifies_as_serial_opener?(2, 1)).to be true
      end
    end

    it 'returns false for zero days' do
      calculator = described_class.new(days_in_period: 7)
      expect(calculator.qualifies_as_serial_opener?(10, 0)).to be false
    end

    it 'returns false for nil days' do
      calculator = described_class.new(days_in_period: nil)
      expect(calculator.qualifies_as_serial_opener?(10, nil)).to be false
    end
  end

  describe 'error handling' do
    let(:calculator) { described_class.new(days_in_period: 7) }

    it 'raises error for unknown behavior type' do
      expect do
        calculator.min_visits_for_behavior(:unknown)
      end.to raise_error(ArgumentError, /Unknown behavior type/)
    end
  end
end
