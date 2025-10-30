# frozen_string_literal: true

module Insights
  module Summaries
    # Service to generate top sites ranking for a user
    # Returns most visited sites sorted by time or visit count
    class TopSitesService < BaseService
      MAX_LIMIT = 50
      MIN_LIMIT = 1
      DEFAULT_LIMIT = 10
      VALID_PERIODS = %w[day week month].freeze
      VALID_SORT_OPTIONS = %w[time visits].freeze

      def initialize(user:, period: 'week', limit: DEFAULT_LIMIT, sort_by: 'time')
        super()
        @user = user
        @period = validate_period(period)
        @limit = sanitize_limit(limit)
        @sort_by = validate_sort_by(sort_by)
      end

      def call
        date_range = calculate_date_range
        visits = fetch_visits(date_range)
        sites = calculate_top_sites(visits)

        success_result(
          data: {
            period: @period,
            start_date: date_range[:start].to_date.to_s,
            end_date: date_range[:end].to_date.to_s,
            sites:
          }
        )
      rescue ActiveRecord::RecordNotFound => e
        handle_error(e, 'User not found', "User not found for top sites: user_id=#{user.id}")
      rescue ActiveRecord::StatementInvalid => e
        error_msg = "Database error in top sites for user_id=#{user.id} " \
                    "period=#{period} limit=#{limit} sort_by=#{sort_by}"
        handle_error(e, 'Database query failed', error_msg)
      rescue ArgumentError => e
        error_msg = "Invalid argument in top sites for user_id=#{user.id} " \
                    "period=#{period} limit=#{limit} sort_by=#{sort_by}"
        handle_error(e, 'Invalid parameters', error_msg)
      end

      private

      attr_reader :user, :period, :limit, :sort_by

      def handle_error(exception, message, log_message)
        log_error(log_message, exception)
        failure_result(message:, errors: [exception.message])
      end

      def validate_period(raw_period)
        return 'week' unless VALID_PERIODS.include?(raw_period.to_s)

        raw_period.to_s
      end

      def validate_sort_by(raw_sort)
        return 'time' unless VALID_SORT_OPTIONS.include?(raw_sort.to_s)

        raw_sort.to_s
      end

      def sanitize_limit(raw_limit)
        raw_limit.to_i.clamp(MIN_LIMIT, MAX_LIMIT)
      end

      def sort_order
        sort_by == 'visits' ? { visit_count: :desc } : { total_time: :desc }
      end

      def calculate_date_range
        # TODO: Add user timezone support (requires user.timezone column)
        # Currently uses Rails.application.config.time_zone (UTC)
        start_time = case period
                     when 'day' then Time.current
                     when 'month' then 30.days.ago
                     else 7.days.ago
                     end
        { start: start_time.beginning_of_day, end: Time.current.end_of_day }
      end

      def fetch_visits(date_range)
        user.page_visits
          .valid_data
          .where('visited_at >= ? AND visited_at <= ?', date_range[:start], date_range[:end])
      end

      def calculate_top_sites(visits)
        weighted_engagement_sql = 'COALESCE(SUM(engagement_rate * COALESCE(duration_seconds, 0)) / ' \
                                  'NULLIF(SUM(COALESCE(duration_seconds, 0)), 0), 0) as avg_engagement'

        visits.group(:domain)
          .select(
            'domain',
            'COUNT(*) as visit_count',
            'COALESCE(SUM(duration_seconds), 0) as total_time',
            weighted_engagement_sql,
            'MIN(visited_at) as first_visit',
            'MAX(visited_at) as last_visit'
          )
          .order(sort_order)
          .limit(limit)
          .map do |row|
          {
            domain: row.domain,
            visits: row.visit_count,
            total_time_seconds: row.total_time.to_i,
            avg_engagement_rate: row.avg_engagement.to_f.round(2),
            first_visit: row.first_visit.iso8601,
            last_visit: row.last_visit.iso8601
          }
        end
      end
    end
  end
end
