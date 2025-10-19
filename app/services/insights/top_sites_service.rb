# frozen_string_literal: true

module Insights
  # Service to generate top sites ranking for a user
  # Returns most visited sites sorted by time or visit count
  class TopSitesService < BaseService
    MAX_LIMIT = 50
    MIN_LIMIT = 1
    DEFAULT_LIMIT = 10

    def initialize(user:, period: 'week', limit: DEFAULT_LIMIT, sort_by: 'time')
      super()
      @user = user
      @period = period
      @limit = sanitize_limit(limit)
      @sort_by = sort_by
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
    rescue StandardError => e
      log_error('Failed to generate top sites', e)
      failure_result(
        message: 'Failed to generate top sites',
        errors: [e.message]
      )
    end

    private

    attr_reader :user, :period, :limit, :sort_by

    def sanitize_limit(raw_limit)
      parsed = raw_limit.to_i
      [[parsed, MIN_LIMIT].max, MAX_LIMIT].min
    end

    def calculate_date_range
      case period
      when 'day'
        { start: Time.current.beginning_of_day, end: Time.current.end_of_day }
      when 'week'
        { start: 7.days.ago.beginning_of_day, end: Time.current.end_of_day }
      when 'month'
        { start: 30.days.ago.beginning_of_day, end: Time.current.end_of_day }
      else
        { start: 7.days.ago.beginning_of_day, end: Time.current.end_of_day }
      end
    end

    def fetch_visits(date_range)
      user.page_visits
        .valid_data
        .where('visited_at >= ? AND visited_at <= ?', date_range[:start], date_range[:end])
    end

    def calculate_top_sites(visits)
      sort_column = sort_by == 'visits' ? 'visit_count' : 'total_time'

      visits.group(:domain)
        .select(
          'domain',
          'COUNT(*) as visit_count',
          'SUM(duration_seconds) as total_time',
          'AVG(engagement_rate) as avg_engagement',
          'MIN(visited_at) as first_visit',
          'MAX(visited_at) as last_visit'
        )
        .order("#{sort_column} DESC")
        .limit(limit)
        .map do |row|
        {
          domain: row.domain,
          visits: row.visit_count,
          total_time_seconds: row.total_time&.to_i || 0,
          avg_engagement_rate: row.avg_engagement ? row.avg_engagement.round(2) : 0.0,
          first_visit: row.first_visit.iso8601,
          last_visit: row.last_visit.iso8601
        }
      end
    end
  end
end
