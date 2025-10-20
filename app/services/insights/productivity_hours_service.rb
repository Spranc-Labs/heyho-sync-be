# frozen_string_literal: true

module Insights
  # Service to analyze productivity patterns by hour and day of week
  # Returns metrics about most/least productive hours and days
  class ProductivityHoursService < BaseService
    VALID_PERIODS = %w[week month].freeze

    def initialize(user:, period: 'week')
      super()
      @user = user
      @period = validate_period(period)
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
    rescue ActiveRecord::RecordNotFound => e
      handle_error(e, 'User not found', "User not found for productivity hours: user_id=#{user.id}")
    rescue ActiveRecord::StatementInvalid => e
      handle_error(e, 'Database query failed',
                   "Database error in productivity hours for user_id=#{user.id} period=#{period}")
    rescue ArgumentError => e
      handle_error(e, 'Invalid parameters',
                   "Invalid argument in productivity hours for user_id=#{user.id} period=#{period}")
    end

    private

    attr_reader :user, :period

    def handle_error(exception, message, log_message)
      log_error(log_message, exception)
      failure_result(message:, errors: [exception.message])
    end

    def validate_period(raw_period)
      return 'week' unless VALID_PERIODS.include?(raw_period.to_s)

      raw_period.to_s
    end

    def calculate_date_range
      # TODO: Add user timezone support (requires user.timezone column)
      # Currently uses Rails.application.config.time_zone (UTC)
      start_time = period == 'month' ? 30.days.ago : 7.days.ago
      { start: start_time.beginning_of_day, end: Time.current.end_of_day }
    end

    def fetch_visits(date_range)
      user.page_visits
        .valid_data
        .where('visited_at >= ? AND visited_at <= ?', date_range[:start], date_range[:end])
    end

    def calculate_hourly_stats(visits)
      # NOTE: EXTRACT(HOUR) uses database timezone (UTC)
      # For user-specific timezones, convert visited_at: EXTRACT(HOUR FROM visited_at AT TIME ZONE 'user_tz')
      weighted_engagement_sql = 'COALESCE(SUM(engagement_rate * COALESCE(duration_seconds, 0)) / ' \
                                'NULLIF(SUM(COALESCE(duration_seconds, 0)), 0), 0) as avg_engagement'

      visits.group('EXTRACT(HOUR FROM visited_at)')
        .select(
          'EXTRACT(HOUR FROM visited_at) as hour',
          weighted_engagement_sql,
          'COALESCE(SUM(duration_seconds), 0) as total_time',
          'COUNT(*) as visit_count'
        )
        .order('hour')
        .map do |row|
        {
          hour: row.hour.to_i,
          avg_engagement: row.avg_engagement.to_f.round(2),
          total_time_seconds: row.total_time.to_i,
          visit_count: row.visit_count
        }
      end
    end

    def calculate_day_stats(visits)
      weighted_engagement_sql = 'COALESCE(SUM(engagement_rate * COALESCE(duration_seconds, 0)) / ' \
                                'NULLIF(SUM(COALESCE(duration_seconds, 0)), 0), 0) as avg_engagement'

      visits.group('EXTRACT(DOW FROM visited_at)')
        .select(
          'EXTRACT(DOW FROM visited_at) as day_num',
          weighted_engagement_sql,
          'COALESCE(SUM(duration_seconds), 0) as total_time'
        )
        .order('day_num')
        .map do |row|
        {
          day: Date::DAYNAMES[row.day_num.to_i],
          avg_engagement: row.avg_engagement.to_f.round(2),
          total_time_seconds: row.total_time.to_i
        }
      end
    end
  end
end
