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
    # Try JWT authentication first
    return if authenticate_with_jwt

    render_error_response(
      message: 'You need to sign in or sign up before continuing.',
      status: 401
    )
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
