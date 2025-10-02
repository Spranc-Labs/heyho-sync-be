# frozen_string_literal: true

class UserPasswordResetKey < ApplicationRecord
  # Configuration
  self.table_name = 'user_password_reset_keys'
  self.primary_key = 'id'

  # Associations
  belongs_to :user, foreign_key: 'id', inverse_of: false

  # Validations
  validates :key, presence: true, format: { with: /\A\d{6}\z/ }
  validates :id, presence: true
  validates :deadline, presence: true

  # Scopes
  scope :for_user, ->(user_id) { where(id: user_id) }
  scope :valid_tokens, -> { where('deadline > ?', Time.current) }

  # Class methods
  def self.find_for_reset(user_id, token)
    find_by(id: user_id, key: token)
  end

  def self.create_or_update_for_user(user, token, deadline: 1.hour.from_now)
    reset_key = find_by(id: user.id)

    if reset_key
      reset_key.update!(key: token, deadline:, email_last_sent: Time.current)
    else
      create!(id: user.id, key: token, deadline:, email_last_sent: Time.current)
    end
  end

  # Instance methods
  def expired?
    deadline < Time.current
  end

  def valid_for_reset?
    !expired?
  end
end
