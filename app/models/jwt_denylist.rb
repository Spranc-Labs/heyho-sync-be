# frozen_string_literal: true

class JwtDenylist < ApplicationRecord
  # Table name
  self.table_name = 'jwt_denylists'

  # Associations
  belongs_to :user

  # Validations
  validates :jti, presence: true, uniqueness: true
  validates :exp, presence: true

  # Scopes
  scope :active, -> { where('exp > ?', Time.current) }

  # Class methods
  def self.jwt_revoked?(payload, user)
    find_by(jti: payload['jti'], user:).present?
  end

  def self.revoke_jwt(payload, user)
    create!(
      jti: payload['jti'],
      user:,
      exp: Time.zone.at(payload['exp'])
    )
  end

  def self.cleanup_expired
    where('exp < ?', Time.current).delete_all
  end
end
