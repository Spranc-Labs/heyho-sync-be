# frozen_string_literal: true

module Insights
  module Summaries
    # Service to generate weekly browsing summary for a user
    # Returns aggregated metrics for a specific week including visits, domains, time, and daily breakdown
    class WeeklySummaryService < BaseService
      def initialize(user:, week: nil)
        super()
        @user = user
        @week_start, @week_end = parse_week(week)
      end

      def call
        visits = fetch_visits

        success_result(
          data: {
            week: format_week_label,
            start_date: @week_start.to_s,
            end_date: @week_end.to_s,
            total_sites_visited: visits.count,
            unique_domains: visits.distinct.count(:domain),
            total_time_seconds: visits.sum(:duration_seconds) || 0,
            active_time_seconds: visits.sum(:active_duration_seconds) || 0,
            avg_engagement_rate: calculate_avg_engagement(visits),
            daily_breakdown: calculate_daily_breakdown(visits),
            top_domains: calculate_top_domains(visits)
          }
        )
      rescue StandardError => e
        log_error('Failed to generate weekly summary', e)
        failure_result(
          message: 'Failed to generate weekly summary',
          errors: [e.message]
        )
      end

      private

      attr_reader :user, :week_start, :week_end

      def parse_week(week_input)
        if week_input.present?
          # Parse ISO week format: "2025-W42"
          parts = week_input.split('-W')
          year = parts[0].to_i
          week_num = parts[1].to_i

          # Validate year and week_num before using Date.commercial
          if year.positive? && week_num.positive?
            start_date = Date.commercial(year, week_num, 1) # Monday
          else
            # Invalid format, fallback to current week
            today = Time.zone.today
            start_date = today.beginning_of_week(:monday)
          end
        else
          # Default to current week (Monday to Sunday)
          today = Time.zone.today
          start_date = today.beginning_of_week(:monday)
        end
        [start_date, start_date + 6.days]
      rescue ArgumentError, TypeError => e
        log_error("Invalid week format: #{week_input}", e)
        # Fall back to current week
        today = Time.zone.today
        start_date = today.beginning_of_week(:monday)
        [start_date, start_date + 6.days]
      end

      def format_week_label
        # Format as ISO week: "2025-W42"
        "#{week_start.year}-W#{week_start.cweek.to_s.rjust(2, "0")}"
      end

      def fetch_visits
        user.page_visits
          .valid_data
          .where('visited_at >= ? AND visited_at <= ?', week_start.beginning_of_day, week_end.end_of_day)
      end

      def calculate_avg_engagement(visits)
        avg = visits.average(:engagement_rate)
        avg ? avg.round(2) : 0.0
      end

      def calculate_daily_breakdown(visits)
        visits.group('DATE(visited_at)')
          .select('DATE(visited_at) as visit_date, COUNT(*) as visit_count, SUM(duration_seconds) as total_time')
          .order('visit_date')
          .map do |row|
          {
            date: row.visit_date.to_s,
            visits: row.visit_count,
            time_seconds: row.total_time&.to_i || 0
          }
        end
      end

      def calculate_top_domains(visits)
        visits.group(:domain)
          .select('domain, COUNT(*) as visit_count, SUM(duration_seconds) as total_time')
          .order('total_time DESC')
          .limit(10)
          .map do |row|
          {
            domain: row.domain,
            visits: row.visit_count,
            time_seconds: row.total_time&.to_i || 0
          }
        end
      end
    end
  end
end
