# frozen_string_literal: true

module Api
  module V1
    # API controller for pattern detection endpoints
    # Provides access to hoarder tabs, serial openers, and research session detection
    class PatternDetectionsController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/pattern_detections/hoarder_tabs
      def hoarder_tabs
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
      rescue StandardError => e
        render_error_response(
          message: 'Failed to detect hoarder tabs',
          errors: [e.message],
          status: :internal_server_error
        )
      end

      # GET /api/v1/pattern_detections/serial_openers
      def serial_openers
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
    end
  end
end
