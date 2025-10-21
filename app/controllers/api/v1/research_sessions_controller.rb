# frozen_string_literal: true

module Api
  module V1
    # API controller for research session CRUD operations
    # rubocop:disable Metrics/ClassLength
    class ResearchSessionsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_research_session, only: %i[show update destroy restore]

      # GET /api/v1/research_sessions
      def index
        sessions = current_user.research_sessions
          .then { |scope| apply_status_filter(scope) }
          .then { |scope| apply_domain_filter(scope) }
          .then { |scope| apply_date_range_filter(scope) }
          .recent
          .limit(params[:limit] || 50)

        render json: {
          success: true,
          data: {
            research_sessions: sessions.as_json(
              include: { research_session_tabs: { only: %i[id url title domain tab_order] } },
              methods: %i[formatted_duration]
            ),
            count: sessions.size
          }
        }
      end

      # GET /api/v1/research_sessions/:id
      def show
        render json: {
          success: true,
          data: {
            research_session: @research_session.as_json(
              include: { research_session_tabs: { only: %i[id url title domain tab_order] } },
              methods: %i[formatted_duration]
            )
          }
        }
      end

      # POST /api/v1/research_sessions
      def create
        session = current_user.research_sessions.build(research_session_params)

        if session.save
          # Add tabs if page_visit_ids provided
          session.add_tabs(params[:page_visit_ids]) if params[:page_visit_ids].present?

          render json: {
            success: true,
            message: 'Research session created',
            data: { research_session: session.as_json(include: :research_session_tabs) }
          }, status: :created
        else
          render_error_response(
            message: 'Failed to create research session',
            errors: session.errors.full_messages
          )
        end
      end

      # PATCH/PUT /api/v1/research_sessions/:id
      def update
        if @research_session.update(research_session_params)
          render json: {
            success: true,
            message: 'Research session updated',
            data: { research_session: @research_session.as_json(include: :research_session_tabs) }
          }
        else
          render_error_response(
            message: 'Failed to update research session',
            errors: @research_session.errors.full_messages
          )
        end
      end

      # DELETE /api/v1/research_sessions/:id
      def destroy
        @research_session.destroy!

        render json: {
          success: true,
          message: 'Research session removed'
        }
      rescue StandardError => e
        render_error_response(
          message: 'Failed to remove research session',
          errors: [e.message],
          status: :internal_server_error
        )
      end

      # POST /api/v1/research_sessions/:id/save
      def save_session
        set_research_session
        @research_session.mark_as_saved!

        render json: {
          success: true,
          message: 'Research session saved',
          data: { research_session: @research_session }
        }
      rescue StandardError => e
        render_error_response(
          message: 'Failed to save session',
          errors: [e.message]
        )
      end

      # POST /api/v1/research_sessions/:id/restore
      def restore
        @research_session.mark_as_restored!

        render json: {
          success: true,
          message: 'Research session restored',
          data: {
            research_session: @research_session,
            tabs: @research_session.tabs_in_order.as_json(only: %i[url title tab_order])
          }
        }
      rescue StandardError => e
        render_error_response(
          message: 'Failed to restore session',
          errors: [e.message]
        )
      end

      # POST /api/v1/research_sessions/:id/dismiss
      def dismiss
        set_research_session
        @research_session.mark_as_dismissed!

        render json: {
          success: true,
          message: 'Research session dismissed',
          data: { research_session: @research_session }
        }
      rescue StandardError => e
        render_error_response(
          message: 'Failed to dismiss session',
          errors: [e.message]
        )
      end

      private

      def set_research_session
        @research_session = current_user.research_sessions.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error_response(
          message: 'Research session not found',
          status: :not_found
        )
      end

      def research_session_params
        params.require(:research_session).permit(
          :session_name,
          :session_start,
          :session_end,
          :tab_count,
          :primary_domain,
          :total_duration_seconds,
          :avg_engagement_rate,
          :status,
          domains: [],
          topics: []
        )
      end

      def apply_status_filter(scope)
        return scope if params[:status].blank?

        scope.where(status: params[:status])
      end

      def apply_domain_filter(scope)
        return scope if params[:domain].blank?

        scope.by_domain(params[:domain])
      end

      def apply_date_range_filter(scope)
        return scope if params[:start_date].blank? || params[:end_date].blank?

        scope.in_date_range(
          Time.zone.parse(params[:start_date]),
          Time.zone.parse(params[:end_date])
        )
      end

      def render_error_response(message:, errors: nil, status: :unprocessable_entity)
        render json: {
          success: false,
          message:,
          errors:
        }, status:
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
