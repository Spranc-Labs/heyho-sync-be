# frozen_string_literal: true

# == Schema Information
#
# Table name: research_sessions
#
#  id                     :bigint           not null, primary key
#  user_id                :bigint           not null
#  session_name           :string           not null
#  session_start          :datetime         not null
#  session_end            :datetime         not null
#  tab_count              :integer          not null
#  primary_domain         :string
#  domains                :string           default([]), is an Array
#  topics                 :string           default([]), is an Array
#  total_duration_seconds :integer
#  avg_engagement_rate    :float
#  status                 :string(50)       default("detected"), not null
#  saved_at               :datetime
#  last_restored_at       :datetime
#  restore_count          :integer          default(0)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  idx_research_sessions_domain       (primary_domain)
#  idx_research_sessions_start        (session_start)
#  idx_research_sessions_user_status  (user_id,status)
#  research_sessions_user_id_idx      (user_id)
#
class ResearchSession < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :research_session_tabs, dependent: :destroy
  has_many :page_visits, through: :research_session_tabs

  # Validations
  validates :session_name, presence: true
  validates :session_start, presence: true
  validates :session_end, presence: true
  validates :tab_count, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[detected saved restored dismissed] }
  validate :session_end_after_start

  # Callbacks
  before_validation :set_saved_at, if: -> { status == 'saved' && saved_at.nil? }

  # Scopes
  scope :detected, -> { where(status: 'detected') }
  scope :saved, -> { where(status: 'saved') }
  scope :restored, -> { where(status: 'restored') }
  scope :dismissed, -> { where(status: 'dismissed') }
  scope :recent, -> { order(session_start: :desc) }
  scope :by_domain, ->(domain) { where(primary_domain: domain) }
  scope :with_topic, ->(topic) { where('? = ANY(topics)', topic) }
  scope :in_date_range, ->(start_date, end_date) { where(session_start: start_date..end_date) }

  # Instance Methods
  def mark_as_saved!
    update!(status: 'saved', saved_at: Time.current)
  end

  def mark_as_restored!
    update!(
      status: 'restored',
      last_restored_at: Time.current,
      restore_count: restore_count + 1
    )
  end

  def mark_as_dismissed!
    update!(status: 'dismissed')
  end

  def detected?
    status == 'detected'
  end

  def saved?
    status == 'saved'
  end

  def dismissed?
    status == 'dismissed'
  end

  def duration_minutes
    return nil unless session_start && session_end

    ((session_end - session_start) / 60).round
  end

  def duration_hours
    return nil unless session_start && session_end

    ((session_end - session_start) / 3600).round(1)
  end

  def formatted_duration
    minutes = duration_minutes
    return nil unless minutes

    if minutes < 60
      "#{minutes} min"
    else
      hours = (minutes / 60.0).round(1)
      "#{hours} hr"
    end
  end

  def add_tabs(page_visit_ids)
    page_visit_ids.each_with_index do |visit_id, index|
      page_visit = PageVisit.find_by(id: visit_id)
      next unless page_visit

      research_session_tabs.create!(
        page_visit_id: visit_id,
        tab_order: index + 1,
        url: page_visit.url,
        title: page_visit.title,
        domain: page_visit.domain
      )
    end
    update!(tab_count: research_session_tabs.count)
  end

  def tabs_in_order
    research_session_tabs.order(:tab_order)
  end

  private

  def session_end_after_start
    return unless session_start && session_end

    errors.add(:session_end, 'must be after session start') if session_end <= session_start
  end

  def set_saved_at
    self.saved_at ||= Time.current
  end
end
