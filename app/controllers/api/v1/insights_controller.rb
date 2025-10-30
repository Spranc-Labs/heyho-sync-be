# frozen_string_literal: true

module Api
  module V1
    # Controller for insights endpoints
    # Provides aggregated browsing data and analytics
    class InsightsController < AuthenticatedController
      # GET /api/v1/insights/daily_summary
      # Returns daily browsing summary for a specific date
      def daily_summary
        result = Insights::Summaries::DailySummaryService.call(
          user: current_user,
          date: params[:date] || Time.zone.today
        )

        render_service_result(result)
      end

      # GET /api/v1/insights/weekly_summary
      # Returns weekly browsing summary for a specific week
      def weekly_summary
        result = Insights::Summaries::WeeklySummaryService.call(
          user: current_user,
          week: params[:week]
        )

        render_service_result(result)
      end

      # GET /api/v1/insights/top_sites
      # Returns top visited sites ranked by time or visits
      def top_sites
        result = Insights::Summaries::TopSitesService.call(
          user: current_user,
          period: params[:period] || 'week',
          limit: params[:limit] || 10,
          sort_by: params[:sort_by] || 'time'
        )

        render_service_result(result)
      end

      # GET /api/v1/insights/recent_activity
      # Returns recent browsing sessions grouped by time gaps
      def recent_activity
        result = Insights::Summaries::RecentActivityService.call(
          user: current_user,
          limit: params[:limit] || 20,
          since: params[:since]
        )

        render_service_result(result)
      end

      # GET /api/v1/insights/productivity_hours
      # Returns productivity metrics by hour and day of week
      def productivity_hours
        result = Insights::Summaries::ProductivityHoursService.call(
          user: current_user,
          period: params[:period] || 'week'
        )

        render_service_result(result)
      end

      private

      def render_service_result(result)
        if result.success?
          render_json_response(
            success: true,
            data: result.data
          )
        else
          render_error_response(
            message: result.message || 'Failed to generate insights',
            errors: result.errors,
            status: :unprocessable_entity
          )
        end
      end
    end
  end
end
