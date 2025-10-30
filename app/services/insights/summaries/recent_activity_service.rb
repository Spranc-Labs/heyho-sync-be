# frozen_string_literal: true

module Insights
  module Summaries
    # Service to generate recent browsing activity sessions for a user
    # Groups visits into sessions based on time gaps and classifies session types
    class RecentActivityService < BaseService
      SESSION_GAP_SECONDS = 600 # 10 minutes
      MAX_LIMIT = 100
      MIN_LIMIT = 1
      DEFAULT_LIMIT = 20
      MAX_VISITS_TO_PROCESS = 1000 # Prevent memory exhaustion

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
      rescue ActiveRecord::RecordNotFound => e
        handle_error(e, 'User not found', "User not found for recent activity: user_id=#{user.id}")
      rescue ActiveRecord::StatementInvalid => e
        handle_error(e, 'Database query failed',
                     "Database error in recent activity for user_id=#{user.id} limit=#{limit} since=#{since}")
      rescue ArgumentError => e
        handle_error(e, 'Invalid parameters',
                     "Invalid argument in recent activity for user_id=#{user.id} limit=#{limit} since=#{since}")
      end

      private

      attr_reader :user, :limit, :since

      def handle_error(exception, message, log_message)
        log_error(log_message, exception)
        failure_result(message:, errors: [exception.message])
      end

      def sanitize_limit(raw_limit)
        raw_limit.to_i.clamp(MIN_LIMIT, MAX_LIMIT)
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
          .limit(MAX_VISITS_TO_PROCESS)
      end

      def group_into_sessions(visits)
        # NOTE: visits are ordered DESC (newest first), so we build sessions backwards
        # The first visit becomes session_end, subsequent visits extend backwards to session_start
        sessions = []
        current_session = nil

        visits.each do |visit|
          if current_session.nil?
            current_session = start_session(visit)
          elsif time_gap(current_session[:session_start], visit.visited_at) > SESSION_GAP_SECONDS
            # Gap too large, finalize current session and start new one
            sessions << finalize_session(current_session)
            current_session = start_session(visit)
          else
            # Continue current session (extending backwards in time)
            add_to_session(current_session, visit)
          end
        end

        # Don't forget the last session
        sessions << finalize_session(current_session) if current_session

        sessions
      end

      def start_session(visit)
        # First visit in DESC order is the session END (most recent)
        {
          session_end: visit.visited_at,
          session_start: visit.visited_at,
          visits: [visit],
          domains: Set.new([visit.domain])
        }
      end

      def add_to_session(session, visit)
        # Since visits are ordered DESC, each new visit is earlier (extends session_start backwards)
        session[:session_start] = visit.visited_at if visit.visited_at < session[:session_start]
        session[:visits] << visit
        session[:domains].add(visit.domain)
      end

      def finalize_session(session)
        duration = (session[:session_end] - session[:session_start]).abs.to_i

        # Calculate weighted engagement (by duration)
        weighted_sum = 0.0
        total_duration = 0
        session[:visits].each do |visit|
          next unless visit.engagement_rate && visit.duration_seconds

          weighted_sum += visit.engagement_rate * visit.duration_seconds
          total_duration += visit.duration_seconds
        end
        avg_engagement = total_duration.positive? ? (weighted_sum / total_duration) : 0.0

        {
          type: classify_session(duration, session[:visits].size),
          started_at: session[:session_start].iso8601,
          ended_at: session[:session_end].iso8601,
          duration_seconds: duration,
          domains: session[:domains].to_a,
          visit_count: session[:visits].size,
          avg_engagement: avg_engagement.round(2)
        }
      end

      def classify_session(duration, visit_count)
        if duration >= 1800 && visit_count >= 10
          'research_session'
        elsif duration >= 600
          'browsing_session'
        elsif visit_count >= 5
          'quick_search'
        else
          'brief_visit'
        end
      end

      def time_gap(time_first, time_second)
        (time_first - time_second).abs
      end
    end
  end
end
