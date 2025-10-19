# frozen_string_literal: true

module Api
  module V1
    class PasswordResetController < BaseController
      # POST /api/v1/reset-password-request
      def request_reset
        result = ::Authentication::PasswordResetService.request_reset(
          email: params[:email]
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
            status: :bad_request
          )
        end
      end

      # POST /api/v1/reset-password
      def reset_password
        result = ::Authentication::PasswordResetService.reset_password(
          email: params[:email],
          reset_code: params[:reset_code],
          new_password: params[:new_password]
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
            status: error_status_for(result.message)
          )
        end
      end

      private

      def error_status_for(message)
        case message
        when 'Email is required', 'Email, reset code, and new password are required'
          :bad_request
        when 'Password reset failed'
          :internal_server_error
        else
          :unprocessable_entity
        end
      end
    end
  end
end
