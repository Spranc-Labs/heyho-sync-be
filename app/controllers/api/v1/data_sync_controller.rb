# frozen_string_literal: true

module Api
  module V1
    class DataSyncController < AuthenticatedController
      # POST /api/v1/data/sync
      def create
        result = DataSyncService.sync(
          user: current_user,
          page_visits: params[:pageVisits],
          tab_aggregates: params[:tabAggregates],
          client_info: extract_client_info
        )

        if result.success?
          render_json_response(
            success: true,
            message: result.message,
            data: result.data
          )
        else
          render_error_response(
            message: result.message,
            errors: result.errors,
            status: error_status_for(result)
          )
        end
      end

      private

      def extract_client_info
        {
          user_agent: request.user_agent,
          ip_address: request.remote_ip,
          browser_extension_version: params[:extensionVersion],
          browser_name: params[:browserName],
          browser_version: params[:browserVersion]
        }.compact
      end

      def error_status_for(result)
        if result.message&.include?('Validation failed') || result.message&.include?('required') ||
           result.message&.include?('Batch size exceeded')
          :bad_request
        else
          :internal_server_error
        end
      end
    end
  end
end
