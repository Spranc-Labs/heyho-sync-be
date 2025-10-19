# frozen_string_literal: true

module Authentication
  class TokenService
    class << self
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

      def decode_jwt_token(token)
        JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })[0]
      rescue JWT::DecodeError, JWT::ExpiredSignature
        nil
      end

      def validate_token(token, user = nil)
        return false if token.blank?

        payload = decode_jwt_token(token)
        return false unless payload

        # If user is provided, check if token belongs to user
        return false if user && payload['sub'] != user.id

        # Check if token is revoked (if JTI is present)
        if payload['jti']
          token_user = user || User.find_by(id: payload['sub'])
          return false if token_user && JwtDenylist.jwt_revoked?(payload, token_user)
        end

        true
      end

      def revoke_token(token)
        payload = decode_jwt_token(token)
        return false unless payload && payload['jti']

        user = User.find_by(id: payload['sub'])
        return false unless user

        JwtDenylist.create!(
          jti: payload['jti'],
          user:,
          exp: Time.zone.at(payload['exp'])
        )
        true
      rescue StandardError => e
        Rails.logger.error "Failed to revoke token: #{e.message}"
        false
      end
    end
  end
end
