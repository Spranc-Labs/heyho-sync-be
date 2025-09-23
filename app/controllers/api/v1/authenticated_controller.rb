# frozen_string_literal: true

require 'jwt'

module Api
  module V1
    class AuthenticatedController < BaseController
      # include Rodauth::Rails.controller # Removed due to routing conflicts
      before_action :require_rodauth_authentication

      protected

      attr_reader :current_user

      private

      def require_rodauth_authentication
        # Try JWT authentication first
        return if authenticate_with_jwt

        # No Rodauth fallback since we moved it to /auth prefix
        render_error_response(
          message: 'You need to sign in or sign up before continuing.',
          status: :unauthorized
        )
      end

      def authenticate_with_jwt
        auth_header = request.headers['Authorization']
        return false unless auth_header&.start_with?('Bearer ')

        token = auth_header.sub('Bearer ', '')

        begin
          payload = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })
          user_id = payload[0]['sub']
          @current_user = User.find(user_id)
          true
        rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound
          false
        end
      end
    end
  end
end
