# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
  end

  protected

  attr_reader :current_user

  private

  def require_authentication
    # Try service-to-service authentication first (for internal API calls)
    return if authenticate_with_service_secret

    # Try JWT authentication
    return if authenticate_with_jwt

    render_error_response(
      message: 'You need to sign in or sign up before continuing.',
      status: 401
    )
  end

  def authenticate_with_service_secret
    service_secret = request.headers['X-Service-Secret']
    return false if service_secret.blank?

    expected_secret = ENV.fetch('SERVICE_SECRET', Rails.application.secret_key_base)
    return false unless ActiveSupport::SecurityUtils.secure_compare(service_secret, expected_secret)

    # Service authenticated - get user ID from header
    heyho_user_id = request.headers['X-HeyHo-User-Id']
    return false if heyho_user_id.blank?

    @current_user = User.find_by(id: heyho_user_id)
    !!@current_user
  rescue StandardError => e
    Rails.logger.error "Service authentication failed: #{e.message}"
    false
  end

  def authenticate_with_jwt
    auth_header = request.headers['Authorization']
    return false unless auth_header&.start_with?('Bearer ')

    token = auth_header.sub('Bearer ', '')
    return false unless ::Authentication::TokenService.validate_token(token)

    payload = ::Authentication::TokenService.decode_jwt_token(token)
    return false unless payload

    @current_user = User.find_by(id: payload['sub'])
    !!@current_user
  rescue StandardError => e
    Rails.logger.error "JWT authentication failed: #{e.message}"
    false
  end

  def current_user_id
    current_user&.id
  end

  def user_signed_in?
    current_user.present?
  end
end
