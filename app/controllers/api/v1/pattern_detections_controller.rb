# frozen_string_literal: true

module Api
  module V1
    # API controller for pattern detection endpoints
    # Provides access to hoarder tabs, serial openers, and research session detection
    class PatternDetectionsController < AuthenticatedController
      # GET /api/v1/pattern_detections/hoarder_tabs
      # Supports both new age-based detection and legacy duration-based detection
      # Query params:
      #   New API (recommended):
      #     - lookback_days: Number of days to analyze (default: 30)
      #   Legacy API (deprecated):
      #     - min_open_time: Minimum open time in minutes
      #     - max_engagement: Maximum engagement rate
      def hoarder_tabs
        # Check if using legacy parameters
        if use_legacy_hoarder_detection?
          render_legacy_hoarder_response
        else
          render_new_hoarder_response
        end
      rescue StandardError => e
        render_error_response(
          message: 'Failed to detect hoarder tabs',
          errors: [e.message],
          status: :internal_server_error
        )
      end

      # GET /api/v1/pattern_detections/serial_openers
      # Supports time-based insights with period presets or custom date ranges
      # Query params:
      #   - period: 'today', 'week', or 'month' (default: 'week')
      #   - start_date: Custom start date (YYYY-MM-DD)
      #   - end_date: Custom end date (YYYY-MM-DD)
      #   - include_comparison: 'true' to include comparison with previous period
      #   - Legacy params still supported: min_visits, max_total_engagement
      def serial_openers
        # Check if using new insights endpoint (has period or date range params)
        if use_insights_service?
          render_insights_response
        else
          render_legacy_response
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

      def use_legacy_hoarder_detection?
        # Use legacy detection if old parameters are explicitly provided
        params[:min_open_time].present? || params[:max_engagement].present?
      end

      def render_new_hoarder_response
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
          limit: params[:limit]&.to_i || 20, # Smart default: 20 tabs
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

      def render_legacy_hoarder_response
        min_open_time = params[:min_open_time]&.to_i&.minutes || HoarderDetectionService::DEFAULT_MIN_OPEN_TIME
        max_engagement = params[:max_engagement]&.to_f || HoarderDetectionService::DEFAULT_MAX_ENGAGEMENT

        tabs = HoarderDetectionService.call(
          current_user,
          min_open_time:,
          max_engagement:
        )

        render json: {
          success: true,
          data: {
            hoarder_tabs: tabs,
            count: tabs.size,
            criteria: {
              min_open_time_minutes: (min_open_time / 60).round,
              max_engagement_rate: max_engagement
            }
          }
        }
      end

      # Serial opener helpers

      def use_insights_service?
        # Use insights service if period or date range params are present
        params[:period].present? || (params[:start_date].present? && params[:end_date].present?)
      end

      def render_insights_response
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
      end

      def render_legacy_response
        min_visits = params[:min_visits]&.to_i || SerialOpenerDetectionService::DEFAULT_MIN_VISITS
        max_total_engagement = params[:max_total_engagement]&.to_i&.minutes ||
                               SerialOpenerDetectionService::DEFAULT_MAX_TOTAL_ENGAGEMENT

        openers = SerialOpenerDetectionService.call(
          current_user,
          min_visits:,
          max_total_engagement:
        )

        render json: {
          success: true,
          data: {
            serial_openers: openers,
            count: openers.size,
            criteria: {
              min_visits:,
              max_total_engagement_minutes: (max_total_engagement / 60).round
            }
          }
        }
      end
    end
  end
end
