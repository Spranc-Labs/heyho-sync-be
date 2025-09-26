# frozen_string_literal: true

module AuthHelpers
  def generate_jwt_token(user)
    payload = {
      sub: user.id,
      jti: SecureRandom.uuid,
      iss: 'heyho-sync-api',
      aud: 'heyho-sync-app',
      iat: Time.current.to_i,
      exp: Time.current.to_i + 3600,
      scope: 'user'
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers(token = nil)
    token ||= generate_jwt_token(current_user) if respond_to?(:current_user)
    { 'Authorization' => "Bearer #{token}" }
  end

  def create_verified_user(attributes = {})
    default_attributes = {
      email: 'test@example.com',
      password_hash: 'hashed_password',
      first_name: 'John',
      last_name: 'Doe',
      status: :verified,
      isVerified: true
    }
    User.create!(default_attributes.merge(attributes))
  end

  def create_unverified_user(attributes = {})
    default_attributes = {
      email: 'unverified@example.com',
      password_hash: 'hashed_password',
      first_name: 'Jane',
      last_name: 'Smith',
      status: :unverified,
      isVerified: false
    }
    User.create!(default_attributes.merge(attributes))
  end

  def create_verification_record(user, code = '123456')
    UserVerificationKey.create!(
      id: user.id,
      key: code,
      requested_at: Time.current,
      email_last_sent: Time.current
    )
    code
  end

  def authenticated_headers_for(user)
    token = generate_jwt_token(user)
    { 'Authorization' => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  config.include AuthHelpers, type: :model
end
