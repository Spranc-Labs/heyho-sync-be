# frozen_string_literal: true

module Api
  module V1
    class VerificationController < BaseController
      # POST /api/v1/verify-email
      def verify_email
        result = ::Authentication::EmailVerificationService.verify_email(
          email: params[:email],
          code: params[:code]
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

      # POST /api/v1/resend-verification
      def resend_verification
        result = ::Authentication::EmailVerificationService.resend_verification(
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
            status: error_status_for(result.message)
          )
        end
      end

      private

      def error_status_for(message)
        case message
        when 'Email and verification code are required', 'Email is required'
          :bad_request
        when 'Verification failed', 'Failed to resend verification code'
          :internal_server_error
        else
          :unprocessable_entity
        end
      end
    end
  end
end
