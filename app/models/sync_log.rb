# frozen_string_literal: true

class SyncLog < ApplicationRecord
  # Constants
  STATUSES = %w[pending processing completed failed].freeze

  # Associations
  belongs_to :user

  # Validations
  validates :synced_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :page_visits_synced, :tab_aggregates_synced,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :recent, -> { order(synced_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id:) }
  scope :by_status, ->(status) { where(status:) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }

  # Class methods
  def self.last_sync_for(user)
    for_user(user.id).completed.recent.first
  end

  def self.success_rate_for(user)
    logs = for_user(user.id)
    return 0.0 if logs.empty?

    (logs.completed.count.to_f / logs.count * 100).round(2)
  end

  # Instance methods
  def total_synced
    page_visits_synced + tab_aggregates_synced
  end

  def success?
    status == 'completed'
  end

  def failure?
    status == 'failed'
  end

  def mark_completed!
    update!(status: 'completed')
  end

  def mark_failed!(messages)
    update!(
      status: 'failed',
      error_messages: Array(messages)
    )
  end
end
