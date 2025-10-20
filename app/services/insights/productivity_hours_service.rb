# frozen_string_literal: true

module Insights
  # Service to analyze productivity patterns by hour and day of week
  # Returns metrics about most/least productive hours and days
  class ProductivityHoursService < BaseService
    def initialize(user:, period: 'week')
      super()
      @user = user
      @period = period
    end

    def call
      date_range = calculate_date_range
      visits = fetch_visits(date_range)

      hourly_stats = calculate_hourly_stats(visits)
      day_stats = calculate_day_stats(visits)

      most_productive = hourly_stats.max_by { |h| h[:avg_engagement] }
      least_productive = hourly_stats.min_by { |h| h[:avg_engagement] }

      success_result(
        data: {
          period: @period,
          most_productive_hour: most_productive&.dig(:hour),
          least_productive_hour: least_productive&.dig(:hour),
          hourly_stats:,
          day_of_week_stats: day_stats
        }
      )
    rescue StandardError => e
      log_error('Failed to generate productivity hours', e)
      failure_result(
        message: 'Failed to generate productivity hours',
        errors: [e.message]
      )
    end

    private

    attr_reader :user, :period

    def calculate_date_range
      start_time = period == 'month' ? 30.days.ago : 7.days.ago
      { start: start_time.beginning_of_day, end: Time.current.end_of_day }
    end

    def fetch_visits(date_range)
      user.page_visits
        .valid_data
        .where('visited_at >= ? AND visited_at <= ?', date_range[:start], date_range[:end])
    end

    def calculate_hourly_stats(visits)
      visits.group('EXTRACT(HOUR FROM visited_at)')
        .select(
          'EXTRACT(HOUR FROM visited_at) as hour',
          'AVG(engagement_rate) as avg_engagement',
          'SUM(duration_seconds) as total_time',
          'COUNT(*) as visit_count'
        )
        .order('hour')
        .map do |row|
        {
          hour: row.hour.to_i,
          avg_engagement: row.avg_engagement ? row.avg_engagement.round(2) : 0.0,
          total_time_seconds: row.total_time&.to_i || 0,
          visit_count: row.visit_count
        }
      end
    end

    def calculate_day_stats(visits)
      visits.group('EXTRACT(DOW FROM visited_at)')
        .select(
          'EXTRACT(DOW FROM visited_at) as day_num',
          'AVG(engagement_rate) as avg_engagement',
          'SUM(duration_seconds) as total_time'
        )
        .order('day_num')
        .map do |row|
        {
          day: Date::DAYNAMES[row.day_num.to_i],
          avg_engagement: row.avg_engagement ? row.avg_engagement.round(2) : 0.0,
          total_time_seconds: row.total_time&.to_i || 0
        }
      end
    end
  end
end
