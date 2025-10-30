# frozen_string_literal: true

# == Schema Information
#
# Table name: reading_list_items
#
#  id                  :bigint           not null, primary key
#  user_id             :bigint           not null
#  page_visit_id       :string
#  url                 :text             not null
#  title               :string
#  domain              :string
#  added_at            :datetime         not null
#  added_from          :string(50)
#  status              :string(50)       default("unread"), not null
#  estimated_read_time :integer
#  notes               :text
#  tags                :string           default([]), is an Array
#  scheduled_for       :datetime
#  completed_at        :datetime
#  dismissed_at        :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  idx_reading_list_added_at          (added_at)
#  idx_reading_list_scheduled         (scheduled_for) WHERE status = 'unread'
#  idx_reading_list_user_status       (user_id,status)
#  idx_reading_list_user_url_unique   (user_id,url) UNIQUE
#  reading_list_items_user_id_idx     (user_id)
#
class ReadingListItem < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :page_visit, primary_key: :id, optional: true

  # Validations
  validates :url, presence: true, uniqueness: { scope: :user_id }
  validates :status, presence: true, inclusion: { in: %w[unread reading completed dismissed] }
  validates :added_from, inclusion: {
    in: %w[hoarder_detection manual_save serial_opener research_session api_import],
    allow_nil: true
  }
  validates :estimated_read_time, numericality: { greater_than: 0, allow_nil: true }

  # Callbacks
  before_validation :set_added_at, on: :create
  before_validation :set_completed_at, if: :completed?
  before_validation :set_dismissed_at, if: :dismissed?

  # Scopes
  scope :unread, -> { where(status: 'unread') }
  scope :reading, -> { where(status: 'reading') }
  scope :completed, -> { where(status: 'completed') }
  scope :dismissed, -> { where(status: 'dismissed') }
  scope :active, -> { where(status: %w[unread reading]) }
  scope :recent, -> { order(added_at: :desc) }
  scope :scheduled, -> { where.not(scheduled_for: nil).where('scheduled_for <= ?', Time.current) }
  scope :by_domain, ->(domain) { where(domain:) }
  scope :with_tags, ->(tags) { where('tags && ARRAY[?]::varchar[]', Array(tags)) }

  # Instance Methods
  def mark_as_reading!
    update!(status: 'reading')
  end

  def mark_as_completed!
    update!(status: 'completed', completed_at: Time.current)
  end

  def mark_as_dismissed!
    update!(status: 'dismissed', dismissed_at: Time.current)
  end

  def completed?
    status == 'completed'
  end

  def dismissed?
    status == 'dismissed'
  end

  def unread?
    status == 'unread'
  end

  def scheduled?
    scheduled_for.present? && scheduled_for <= Time.current
  end

  def estimated_read_minutes
    return nil unless estimated_read_time

    (estimated_read_time / 60.0).ceil
  end

  private

  def set_added_at
    self.added_at ||= Time.current
  end

  def set_completed_at
    self.completed_at ||= Time.current if status == 'completed' && completed_at.nil?
  end

  def set_dismissed_at
    self.dismissed_at ||= Time.current if status == 'dismissed' && dismissed_at.nil?
  end
end
