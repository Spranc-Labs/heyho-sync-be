# frozen_string_literal: true

module Tokenable
  extend ActiveSupport::Concern

  included do
    has_many :jwt_denylists, dependent: :destroy
    # TODO: Enable when refresh_tokens table is created
    # has_many :refresh_tokens, dependent: :destroy
  end

  def generate_jwt_token
    ::Authentication::TokenService.generate_jwt_token(self)
  end

  def revoke_jwt_token(token)
    ::Authentication::TokenService.revoke_token(token)
  end

  def valid_jwt_token?(token)
    ::Authentication::TokenService.validate_token(token, self)
  end

  def active_refresh_tokens
    # TODO: Enable when refresh_tokens table is created
    # refresh_tokens.active
    []
  end

  def revoke_all_tokens!
    # TODO: Enable when refresh_tokens table is created
    # refresh_tokens.update_all(revoked_at: Time.current)

    # Mark all JWT tokens as expired by setting their exp time
    jwt_denylists.create!(
      jti: SecureRandom.uuid, # This will effectively invalidate all tokens
      exp: 1.hour.from_now
    )
  end
end
