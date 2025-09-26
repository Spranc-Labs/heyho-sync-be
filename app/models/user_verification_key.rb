# frozen_string_literal: true

class UserVerificationKey < ApplicationRecord
  # Configuration
  self.table_name = 'user_verification_keys'
  self.primary_key = 'id'

  # Associations
  belongs_to :user, foreign_key: 'id', inverse_of: false

  # Validations
  validates :key, presence: true, format: { with: /\A\d{6}\z/ }
  validates :id, presence: true

  # Scopes
  scope :for_user, ->(user_id) { where(id: user_id) }

  # Class methods
  def self.find_for_verification(user_id, code)
    find_by(id: user_id, key: code)
  end

  def self.create_or_update_for_user(user, code)
    verification_key = find_by(id: user.id)

    if verification_key
      verification_key.update!(key: code)
    else
      create!(id: user.id, key: code)
    end
  end

  # Instance methods
  def expired?
    # TODO: Add expiration logic based on requested_at or email_last_sent
    false
  end
end
