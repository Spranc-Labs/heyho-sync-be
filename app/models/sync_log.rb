# frozen_string_literal: true

class SyncLog < ApplicationRecord
  # Constants
  STATUSES = %w[pending processing completed failed].freeze

  # Associations
  belongs_to :user

  # Validations
  validates :synced_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :page_visits_synced, :tab_aggregates_synced, :rejected_records_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :recent, -> { order(synced_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id:) }
  scope :by_status, ->(status) { where(status:) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :with_validation_errors, -> { where('rejected_records_count > 0') }
  scope :clean, -> { where(rejected_records_count: 0) }

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

  def add_validation_error(record_id:, record_type:, field:, message:, value: nil)
    error = {
      record_id:,
      record_type:,
      field:,
      message:,
      value:,
      timestamp: Time.current.iso8601
    }.compact

    self.validation_errors = validation_errors + [error]
    self.rejected_records_count += 1
  end

  def validation_errors?
    rejected_records_count.positive?
  end

  def data_quality_score
    return 100.0 if total_records.zero?

    ((total_synced.to_f / total_records) * 100).round(2)
  end

  def total_records
    total_synced + rejected_records_count
  end
end
