# frozen_string_literal: true

# AuthorizationCode model for OAuth2 authorization code flow
# Stores temporary authorization codes that can be exchanged for user info
class AuthorizationCode < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :code, presence: true, uniqueness: true
  validates :client_id, presence: true
  validates :redirect_uri, presence: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
  validates :expires_at, presence: true
  validates :scope, presence: true

  # Scopes
  scope :valid, -> { where(used: false).where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :unused, -> { where(used: false) }

  # Constants
  CODE_EXPIRY_SECONDS = 10.minutes.to_i
  VALID_CLIENTS = %w[syrupy].freeze
  VALID_SCOPES = %w[browsing_data:read profile:read].freeze

  # Class methods
  def self.generate_for(user:, client_id:, redirect_uri:, scope: 'browsing_data:read')
    raise ArgumentError, "Invalid client_id: #{client_id}" unless VALID_CLIENTS.include?(client_id)
    raise ArgumentError, "Invalid scope: #{scope}" unless VALID_SCOPES.include?(scope)

    create!(
      user: user,
      code: generate_unique_code,
      client_id: client_id,
      redirect_uri: redirect_uri,
      scope: scope,
      expires_at: CODE_EXPIRY_SECONDS.seconds.from_now
    )
  end

  def self.generate_unique_code
    loop do
      code = SecureRandom.urlsafe_base64(32)
      break code unless exists?(code: code)
    end
  end

  # Instance methods
  def code_valid?
    !used && !expired?
  end

  def expired?
    expires_at <= Time.current
  end

  def consume!
    raise StandardError, 'Code already used' if used
    raise StandardError, 'Code expired' if expired?

    update!(used: true, used_at: Time.current)
    user
  end

  def seconds_until_expiry
    return 0 if expired?

    (expires_at - Time.current).to_i
  end
end
