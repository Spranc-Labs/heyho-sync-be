# frozen_string_literal: true

module Insights
  module Summaries
    # Service to generate daily browsing summary for a user
    # Returns aggregated metrics for a specific date including visits, domains, time, and engagement
    class DailySummaryService < BaseService
    def initialize(user:, date: Time.zone.today)
      super()
      @user = user
      @date = parse_date(date)
    end

    def call
      visits = fetch_visits

      success_result(
        data: {
          date: @date.to_s,
          total_sites_visited: visits.count,
          unique_domains: visits.distinct.count(:domain),
          total_time_seconds: visits.sum(:duration_seconds) || 0,
          active_time_seconds: visits.sum(:active_duration_seconds) || 0,
          avg_engagement_rate: calculate_avg_engagement(visits),
          top_domain: calculate_top_domain(visits),
          hourly_breakdown: calculate_hourly_breakdown(visits)
        }
      )
    rescue StandardError => e
      log_error('Failed to generate daily summary', e)
      failure_result(
        message: 'Failed to generate daily summary',
        errors: [e.message]
      )
    end

    private

    attr_reader :user, :date

    def parse_date(date_input)
      return date_input if date_input.is_a?(Date)

      Date.parse(date_input.to_s)
    rescue ArgumentError => e
      log_error("Invalid date format: #{date_input}", e)
      Time.zone.today
    end

    def fetch_visits
      user.page_visits
        .valid_data
        .where('DATE(visited_at) = ?', date)
    end

    def calculate_avg_engagement(visits)
      avg = visits.average(:engagement_rate)
      avg ? avg.round(2) : 0.0
    end

    def calculate_top_domain(visits)
      top = visits.group(:domain)
        .select('domain, COUNT(*) as visit_count, SUM(duration_seconds) as total_time')
        .order('total_time DESC')
        .first

      return nil unless top

      {
        domain: top.domain,
        visits: top.visit_count,
        time_seconds: top.total_time&.to_i || 0
      }
    end

    def calculate_hourly_breakdown(visits)
      visits.group('EXTRACT(HOUR FROM visited_at)')
        .select('EXTRACT(HOUR FROM visited_at) as hour, COUNT(*) as visit_count, SUM(duration_seconds) as total_time')
        .order('hour')
        .map do |row|
        {
          hour: row.hour.to_i,
          visits: row.visit_count,
          time_seconds: row.total_time&.to_i || 0
        }
      end
    end
    end
  end
end
