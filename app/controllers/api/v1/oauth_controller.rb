# frozen_string_literal: true

module Api
  module V1
    # OAuth2 authorization controller
    # Implements simplified OAuth2 authorization code flow for Syrupy integration
    class OauthController < BaseController
      # Don't require authentication - this will be a public OAuth flow
      # Users will login through a form on the authorization page

      # GET /api/v1/oauth/authorize
      # Shows authorization page info (public endpoint)
      def authorize
        return unless validate_authorize_params!

        # Return authorization page information
        render json: {
          client_id: params[:client_id],
          redirect_uri: params[:redirect_uri],
          scope: params[:scope] || 'browsing_data:read',
          client_name: 'Syrupy',
          requires_login: true
        }
      end

      # POST /api/v1/oauth/authorize
      # User grants authorization (requires email and password)
      def create_authorization
        return unless validate_authorize_params!

        # Authenticate user with email and password
        email = params[:email]
        password = params[:password]

        unless email.present? && password.present?
          return render json: {
            error: 'invalid_request',
            error_description: 'Email and password are required'
          }, status: :bad_request
        end

        # Find and authenticate user
        user = User.find_by(email: email.downcase)
        unless user&.valid_password?(password)
          return render json: {
            error: 'invalid_grant',
            error_description: 'Invalid email or password'
          }, status: :unauthorized
        end

        # Generate authorization code
        auth_code = AuthorizationCode.generate_for(
          user: user,
          client_id: params[:client_id],
          redirect_uri: params[:redirect_uri],
          scope: params[:scope] || 'browsing_data:read'
        )

        # Return authorization code
        render json: {
          code: auth_code.code,
          redirect_uri: params[:redirect_uri],
          expires_in: auth_code.seconds_until_expiry
        }, status: :created
      rescue ArgumentError => e
        render json: { error: 'invalid_request', error_description: e.message }, status: :bad_request
      end

      # POST /api/v1/oauth/token
      # Exchange authorization code for user info
      def token
        validate_token_params!

        # Find and consume authorization code
        auth_code = AuthorizationCode.find_by(code: params[:code])

        unless auth_code
          return render json: {
            error: 'invalid_grant',
            error_description: 'Invalid authorization code'
          }, status: :bad_request
        end

        # Validate client and redirect URI
        unless auth_code.client_id == params[:client_id]
          return render json: {
            error: 'invalid_client',
            error_description: 'Client ID mismatch'
          }, status: :bad_request
        end

        unless auth_code.redirect_uri == params[:redirect_uri]
          return render json: {
            error: 'invalid_grant',
            error_description: 'Redirect URI mismatch'
          }, status: :bad_request
        end

        # Consume the code and get user
        user = auth_code.consume!

        # Return user information
        render json: {
          user_id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          scope: auth_code.scope
        }
      rescue StandardError => e
        render json: {
          error: 'invalid_grant',
          error_description: e.message
        }, status: :bad_request
      end

      private

      def validate_authorize_params!
        required_params = %i[client_id redirect_uri]
        missing = required_params.select { |p| params[p].blank? }

        if missing.any?
          render json: {
            error: 'invalid_request',
            error_description: "Missing required parameters: #{missing.join(", ")}"
          }, status: :bad_request
          return false
        end

        unless AuthorizationCode::VALID_CLIENTS.include?(params[:client_id])
          render json: {
            error: 'invalid_client',
            error_description: 'Unknown client_id'
          }, status: :bad_request
          return false
        end

        true
      end

      def validate_token_params!
        required_params = %i[code client_id redirect_uri]
        missing = required_params.select { |p| params[p].blank? }

        return true if missing.empty?

        render json: {
          error: 'invalid_request',
          error_description: "Missing required parameters: #{missing.join(", ")}"
        }, status: :bad_request
        false
      end
    end
  end
end
