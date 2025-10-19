# frozen_string_literal: true

module Api
  module V1
    # rubocop:disable Metrics/ClassLength
    # Controller provides multiple insight endpoints with focused helper methods.
    # Complexity metrics are all within limits. Splitting would reduce cohesion.
    class InsightsController < BaseController
      before_action :authenticate_request
      before_action :set_target_user

      # GET /api/v1/insights/daily_summary
      def daily_summary
        date = parse_date(params[:date]) || Time.current.beginning_of_day
        today_visits, yesterday_visits = fetch_visits_for_date_range(date)

        today_stats = calculate_visit_stats(today_visits)
        yesterday_stats = calculate_visit_stats(yesterday_visits)

        render_json_response(
          success: true,
          data: {
            date: date.to_date.to_s,
            **today_stats,
            comparison: build_comparison(today_stats, yesterday_stats)
          }
        )
      end

      # GET /api/v1/insights/top_sites
      def top_sites
        period = params[:period] || 'today'
        limit = [params[:limit]&.to_i || 10, 50].min

        date_range = build_date_range(period)
        visits = @target_user.page_visits.where(visited_at: date_range).where.not(domain: nil)
        total_time = visits.sum(:duration_seconds) || 1 # Avoid division by zero
        sites = calculate_top_sites(visits, limit, total_time)

        render_json_response(success: true, data: { period:, sites: })
      end

      # GET /api/v1/insights/recent_activity
      def recent_activity
        limit = [params[:limit]&.to_i || 20, 100].min
        visits = @target_user.page_visits.order(visited_at: :desc).limit(limit)
        sessions = visits.map { |visit| build_session_data(visit) }

        render_json_response(success: true, data: { sessions: })
      end

      private

      # Authenticate using JWT token or service secret
      def authenticate_request
        return true if valid_service_token?
        return false unless valid_auth_header?

        decode_and_validate_jwt_token
      end

      def valid_service_token?
        service_token = request.headers['X-Service-Token']
        return false unless service_token.present? && service_token == ENV['SERVICE_SECRET']

        Rails.logger.info 'DEBUG AUTH: Using service token'
        true
      end

      def valid_auth_header?
        auth_header = request.headers['Authorization']
        return true if auth_header&.start_with?('Bearer ')

        Rails.logger.info 'DEBUG AUTH: No valid auth header'
        render_error_response(message: 'Authentication required', status: :unauthorized)
        false
      end

      def decode_and_validate_jwt_token
        auth_header = request.headers['Authorization']
        token = auth_header.sub('Bearer ', '')
        Rails.logger.info "DEBUG AUTH: Token=#{token[0..20]}..."

        @decoded_token = ::Authentication::TokenService.decode_jwt_token(token)
        Rails.logger.info "DEBUG AUTH: decoded_token=#{@decoded_token.inspect}"

        return true if @decoded_token

        render_error_response(message: 'Invalid or expired token', status: :unauthorized)
        false
      end

      # Find the target user based on email parameter or JWT token
      def set_target_user
        @target_user = find_target_user
        Rails.logger.info "DEBUG: target_user=#{@target_user.inspect}"

        return true if @target_user

        render_error_response(message: 'User not found', status: :not_found)
        false
      end

      def find_target_user
        email = params[:email].presence || params[:user_email].presence
        Rails.logger.info "DEBUG: email=#{email.inspect}, decoded_token=#{@decoded_token.inspect}"

        if email.present?
          User.find_by(email:) # Service-to-service call with email parameter
        elsif @decoded_token
          Rails.logger.info "DEBUG: Looking for user with id=#{@decoded_token["sub"]}"
          User.find_by(id: @decoded_token['sub']) # Direct user call with JWT
        end
      end

      def parse_date(date_string)
        return nil unless date_string

        Date.parse(date_string).beginning_of_day
      rescue ArgumentError
        nil
      end

      def fetch_visits_for_date_range(date)
        yesterday = date - 1.day
        today_visits = @target_user.page_visits.where('visited_at >= ? AND visited_at < ?', date, date + 1.day)
        yesterday_visits = @target_user.page_visits.where('visited_at >= ? AND visited_at < ?', yesterday, date)
        [today_visits, yesterday_visits]
      end

      def calculate_visit_stats(visits)
        {
          total_time_seconds: visits.sum(:duration_seconds) || 0,
          total_sessions: visits.count,
          unique_sites: visits.distinct.count(:domain),
          unique_domains: visits.where.not(domain: nil).distinct.pluck(:domain).count,
          most_visited_site: find_most_visited_site(visits),
          longest_session: find_longest_session(visits)
        }
      end

      def find_most_visited_site(visits)
        most_visited = visits.group(:domain).count.max_by { |_domain, count| count }
        most_visited&.first
      end

      def find_longest_session(visits)
        longest = visits.order(duration_seconds: :desc).first
        return nil unless longest&.duration_seconds

        { url: longest.url, duration: longest.duration_seconds }
      end

      def build_comparison(today_stats, yesterday_stats)
        {
          vs_yesterday: {
            time_diff: format_diff(today_stats[:total_time_seconds] - yesterday_stats[:total_time_seconds]),
            sessions_diff: format_diff(today_stats[:total_sessions] - yesterday_stats[:total_sessions])
          }
        }
      end

      def build_date_range(period)
        case period
        when 'week'
          7.days.ago.beginning_of_day..Time.current.end_of_day
        when 'month'
          30.days.ago.beginning_of_day..Time.current.end_of_day
        else # 'today' or any other value defaults to today
          Time.current.all_day
        end
      end

      def calculate_top_sites(visits, limit, total_time)
        visits.group(:domain)
          .select('domain, SUM(duration_seconds) as total_time, COUNT(*) as visit_count, ' \
                  'AVG(duration_seconds) as avg_duration, MAX(visited_at) as last_visit')
          .order('total_time DESC')
          .limit(limit)
          .map { |site| build_site_stats(site, total_time) }
      end

      def build_site_stats(site, total_time)
        {
          domain: site.domain,
          total_time_seconds: site.total_time.to_i,
          visit_count: site.visit_count,
          percentage_of_total: calculate_percentage(site.total_time, total_time),
          avg_session_duration: site.avg_duration.to_i,
          last_visited_at: site.last_visit
        }
      end

      def calculate_percentage(site_time, total_time)
        return 0 unless total_time.positive?

        ((site_time.to_f / total_time) * 100).round(1)
      end

      def build_session_data(visit)
        duration = visit.duration_seconds || 0
        {
          id: visit.id,
          url: visit.url,
          title: visit.title,
          domain: visit.domain,
          visited_at: visit.visited_at,
          duration:,
          is_long_session: duration > 1800 # 30 minutes
        }
      end

      def format_diff(value)
        return value.to_s if value.zero?

        value.positive? ? "+#{value}" : value.to_s
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
