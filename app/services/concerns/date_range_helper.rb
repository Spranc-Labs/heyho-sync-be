# frozen_string_literal: true

# Helper module for parsing and calculating date ranges
# Supports period presets (today, week, month) and custom date ranges
module DateRangeHelper
  VALID_PERIODS = %w[today week month].freeze

  # Parse date range from either period preset or custom start/end dates
  # @param period [String, nil] Period preset ('today', 'week', 'month')
  # @param start_date [String, Date, nil] Custom start date
  # @param end_date [String, Date, nil] Custom end date
  # @return [Hash] Hash with :start and :end Time objects, :period name, :is_custom boolean
  def parse_date_range(period: nil, start_date: nil, end_date: nil)
    # Custom date range takes precedence
    return parse_custom_range(start_date, end_date) if start_date.present? && end_date.present?

    # Use period preset
    validated_period = validate_period(period)
    calculate_period_range(validated_period)
  end

  # Calculate the previous period range for comparison
  # @param current_range [Hash] Current period range from parse_date_range
  # @return [Hash] Previous period range with same duration
  def previous_period_range(current_range)
    duration = current_range[:end] - current_range[:start]
    previous_end = current_range[:start] - 1.second
    # Fix: Ensure previous_start is at beginning of day to match the period length
    previous_start = (current_range[:start] - duration).beginning_of_day

    {
      start: previous_start,
      end: previous_end,
      period: "previous_#{current_range[:period]}",
      is_custom: current_range[:is_custom]
    }
  end

  # Calculate how many days are in the date range
  # @param date_range [Hash] Date range from parse_date_range
  # @return [Float] Number of days in the range
  def days_in_range(date_range)
    ((date_range[:end] - date_range[:start]) / 1.day).round(2)
  end

  private

  def validate_period(period)
    return 'week' if period.blank? || VALID_PERIODS.exclude?(period.to_s)

    period.to_s
  end

  def calculate_period_range(period)
    end_time = Time.current.end_of_day

    start_time = case period
                 when 'today'
                   Time.current.beginning_of_day
                 when 'month'
                   30.days.ago.beginning_of_day
                 else # 'week'
                   7.days.ago.beginning_of_day
                 end

    {
      start: start_time,
      end: end_time,
      period:,
      is_custom: false
    }
  end

  def parse_custom_range(start_date, end_date)
    start_time = parse_date(start_date).beginning_of_day
    end_time = parse_date(end_date).end_of_day

    # Validate that start is before end
    raise ArgumentError, 'start_date must be before end_date' if start_time > end_time

    # Limit to 90 days max to prevent performance issues
    days_diff = ((end_time - start_time) / 1.day).round
    raise ArgumentError, 'Date range cannot exceed 90 days' if days_diff > 90

    {
      start: start_time,
      end: end_time,
      period: 'custom',
      is_custom: true
    }
  end

  def parse_date(date_input)
    case date_input
    when Date, Time, ActiveSupport::TimeWithZone
      date_input.to_time
    when String
      Date.parse(date_input).to_time
    else
      raise ArgumentError, "Invalid date format: #{date_input}"
    end
  rescue Date::Error => e
    raise ArgumentError, "Failed to parse date: #{e.message}"
  end
end
