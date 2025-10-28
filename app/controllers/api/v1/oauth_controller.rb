# frozen_string_literal: true

module Api
  module V1
    # OAuth2 authorization controller
    # Implements simplified OAuth2 authorization code flow for Syrupy integration
    class OauthController < AuthenticatedController
      skip_before_action :require_authentication, only: [:token]

      # GET /api/v1/oauth/authorize
      # Shows authorization page (or returns auth details for SPA)
      def authorize
        validate_authorize_params!

        # In a traditional OAuth flow, this would render an authorization page
        # For our SPA, we return the authorization details
        render json: {
          client_id: params[:client_id],
          redirect_uri: params[:redirect_uri],
          scope: params[:scope] || 'browsing_data:read',
          user: {
            id: current_user.id,
            email: current_user.email,
            first_name: current_user.first_name,
            last_name: current_user.last_name
          }
        }
      end

      # POST /api/v1/oauth/authorize
      # User grants authorization
      def create_authorization
        validate_authorize_params!

        # Generate authorization code
        auth_code = AuthorizationCode.generate_for(
          user: current_user,
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
