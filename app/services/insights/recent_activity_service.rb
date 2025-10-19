# frozen_string_literal: true

module Insights
  # Service to generate recent browsing activity sessions for a user
  # Groups visits into sessions based on time gaps and classifies session types
  class RecentActivityService < BaseService
    SESSION_GAP_SECONDS = 600 # 10 minutes
    MAX_LIMIT = 100
    MIN_LIMIT = 1
    DEFAULT_LIMIT = 20

    def initialize(user:, limit: DEFAULT_LIMIT, since: nil)
      super()
      @user = user
      @limit = sanitize_limit(limit)
      @since = parse_since(since)
    end

    def call
      visits = fetch_visits
      sessions = group_into_sessions(visits)

      success_result(
        data: {
          activities: sessions.take(limit)
        }
      )
    rescue StandardError => e
      log_error('Failed to generate recent activity', e)
      failure_result(
        message: 'Failed to generate recent activity',
        errors: [e.message]
      )
    end

    private

    attr_reader :user, :limit, :since

    def sanitize_limit(raw_limit)
      parsed = raw_limit.to_i
      [[parsed, MIN_LIMIT].max, MAX_LIMIT].min
    end

    def parse_since(since_input)
      return 24.hours.ago if since_input.blank?

      Time.zone.parse(since_input.to_s)
    rescue ArgumentError => e
      log_error("Invalid since parameter: #{since_input}", e)
      24.hours.ago
    end

    def fetch_visits
      user.page_visits
        .valid_data
        .where('visited_at >= ?', since)
        .order(visited_at: :desc)
    end

    def group_into_sessions(visits)
      sessions = []
      current_session = nil

      visits.each do |visit|
        if current_session.nil?
          current_session = start_session(visit)
        elsif time_gap(current_session[:ended_at], visit.visited_at) > SESSION_GAP_SECONDS
          # Gap too large, finalize current session and start new one
          sessions << finalize_session(current_session)
          current_session = start_session(visit)
        else
          # Continue current session
          add_to_session(current_session, visit)
        end
      end

      # Don't forget the last session
      sessions << finalize_session(current_session) if current_session

      sessions
    end

    def start_session(visit)
      {
        started_at: visit.visited_at,
        ended_at: visit.visited_at,
        visits: [visit],
        domains: Set.new([visit.domain])
      }
    end

    def add_to_session(session, visit)
      # Since visits are ordered desc, earlier times are "ended_at"
      session[:ended_at] = visit.visited_at if visit.visited_at < session[:ended_at]
      session[:visits] << visit
      session[:domains].add(visit.domain)
    end

    def finalize_session(session)
      duration = (session[:started_at] - session[:ended_at]).abs.to_i
      engagements = session[:visits].filter_map(&:engagement_rate)
      avg_engagement = engagements.empty? ? 0.0 : (engagements.sum / engagements.size.to_f)

      {
        type: classify_session(duration, session[:visits].size),
        started_at: session[:ended_at].iso8601, # Reversed because ordered desc
        ended_at: session[:started_at].iso8601,
        duration_seconds: duration,
        domains: session[:domains].to_a,
        visit_count: session[:visits].size,
        avg_engagement: avg_engagement.round(2)
      }
    end

    def classify_session(duration, visit_count)
      if duration > 1800 && visit_count > 10
        'research_session'
      elsif duration > 600
        'browsing_session'
      elsif visit_count > 5
        'quick_search'
      else
        'brief_visit'
      end
    end

    def time_gap(time1, time2)
      (time1 - time2).abs
    end
  end
end
