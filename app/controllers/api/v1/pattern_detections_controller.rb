# frozen_string_literal: true

module Api
  module V1
    # API controller for pattern detection endpoints
    # Provides access to hoarder tabs, serial openers, and research session detection
    class PatternDetectionsController < AuthenticatedController
      # GET /api/v1/pattern_detections/hoarder_tabs
      # Age-based hoarder tab detection
      # Query params:
      #   - lookback_days: Number of days to analyze (default: 30)
      #   - min_score: Minimum hoarder score (default: 60)
      #   - age_min: Minimum tab age in days
      #   - domain: Filter by specific domain
      #   - exclude_domains: Comma-separated domains to exclude
      #   - limit: Max number of results (default: 1000)
      #   - sort_by: Sort method (default: 'value_rank')
      def hoarder_tabs
        render_hoarder_response
      rescue StandardError => e
        render_error_response(
          message: 'Failed to detect hoarder tabs',
          errors: [e.message],
          status: :internal_server_error
        )
      end

      # GET /api/v1/pattern_detections/serial_openers
      # Time-based insights with period presets or custom date ranges
      # Query params:
      #   - period: 'today', 'week', or 'month' (default: 'week')
      #   - start_date: Custom start date (YYYY-MM-DD)
      #   - end_date: Custom end date (YYYY-MM-DD)
      #   - include_comparison: 'true' to include comparison with previous period
      def serial_openers
        result = Insights::SerialOpenerInsightsService.call(
          user: current_user,
          period: params[:period],
          start_date: params[:start_date],
          end_date: params[:end_date],
          include_comparison: params[:include_comparison] == 'true'
        )

        if result.success?
          render json: {
            success: true,
            data: result.data
          }
        else
          render_error_response(
            message: result.message || 'Failed to generate insights',
            errors: result.errors,
            status: :unprocessable_entity
          )
        end
      rescue StandardError => e
        render_error_response(
          message: 'Failed to detect serial openers',
          errors: [e.message],
          status: :internal_server_error
        )
      end

      # GET /api/v1/pattern_detections/research_sessions
      def research_sessions
        detection_params = research_session_params

        sessions = ResearchSessionDetectionService.call(current_user, **detection_params)

        render json: {
          success: true,
          data: {
            research_sessions: sessions,
            count: sessions.size,
            criteria: format_session_criteria(detection_params)
          }
        }
      rescue StandardError => e
        render_error_response(
          message: 'Failed to detect research sessions',
          errors: [e.message],
          status: :internal_server_error
        )
      end

      private

      def render_error_response(message:, errors: nil, status: :unprocessable_entity)
        render json: {
          success: false,
          message:,
          errors:
        }, status:
      end

      def research_session_params
        {
          min_tabs: params[:min_tabs]&.to_i || ResearchSessionDetectionService::DEFAULT_MIN_TABS,
          time_window: params[:time_window]&.to_i&.minutes || ResearchSessionDetectionService::DEFAULT_TIME_WINDOW,
          min_duration: params[:min_duration]&.to_i&.minutes || ResearchSessionDetectionService::DEFAULT_MIN_DURATION
        }
      end

      def format_session_criteria(detection_params)
        {
          min_tabs: detection_params[:min_tabs],
          time_window_minutes: (detection_params[:time_window] / 60).round,
          min_duration_minutes: (detection_params[:min_duration] / 60).round
        }
      end

      # Hoarder tab helpers

      def render_hoarder_response
        lookback_days = params[:lookback_days]&.to_i || HoarderDetectionService::DEFAULT_LOOKBACK_DAYS

        # Parse filter parameters with smart defaults
        filters = parse_hoarder_filters

        # Get all tabs (before filters) for summary
        all_tabs = HoarderDetectionService.call(current_user, lookback_days:, filters: {})

        # Get filtered tabs
        filtered_tabs = HoarderDetectionService.call(current_user, lookback_days:, filters:)

        # Generate summary
        summary = generate_hoarder_summary(all_tabs, filtered_tabs, filters)

        render json: {
          success: true,
          data: {
            summary:,
            hoarder_tabs: filtered_tabs,
            count: filtered_tabs.size
          }
        }
      end

      def parse_hoarder_filters
        {
          min_score: params[:min_score]&.to_f,
          age_min: params[:age_min]&.to_f,
          domain: params[:domain],
          exclude_domains: params[:exclude_domains]&.split(',')&.map(&:strip),
          limit: params[:limit]&.to_i || 1000, # High default to get all tabs (or pass limit param for fewer)
          sort_by: params[:sort_by] || 'value_rank' # Smart default: value-based ranking
        }.compact
      end

      def generate_hoarder_summary(all_tabs, filtered_tabs, filters)
        # Domain breakdown (noise domains)
        domain_counts = all_tabs.group_by { |t| t[:domain] }
          .transform_values(&:size)
          .sort_by { |_k, v| -v }
          .first(5)
          .to_h

        {
          total_detected: all_tabs.size,
          showing: filtered_tabs.size,
          detection_method: 'age_based_v2',
          filters_applied: filters.select { |_k, v| v.present? },
          top_domains: domain_counts
        }
      end
    end
  end
end
