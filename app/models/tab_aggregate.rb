# frozen_string_literal: true

class TabAggregate < ApplicationRecord
  # Associations
  belongs_to :page_visit

  # Validations
  validates :total_time_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :active_time_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :scroll_depth_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
                                   allow_nil: true
  # closed_at can be nil for tabs whose status is unknown (no closure tracking data)

  # Custom validation
  validate :active_time_not_greater_than_total_time

  private

  def active_time_not_greater_than_total_time
    return unless active_time_seconds && total_time_seconds

    return unless active_time_seconds > total_time_seconds

    errors.add(:active_time_seconds, 'cannot be greater than total time')
  end
end
