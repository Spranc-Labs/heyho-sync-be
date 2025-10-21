# frozen_string_literal: true

# == Schema Information
#
# Table name: research_session_tabs
#
#  id                   :bigint           not null, primary key
#  research_session_id  :bigint           not null
#  page_visit_id        :string           not null
#  tab_order            :integer
#  url                  :string           not null
#  title                :string
#  domain               :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  idx_session_tabs_order              (research_session_id,tab_order)
#  idx_session_tabs_page_visit         (page_visit_id)
#  research_session_tabs_research_session_id_idx  (research_session_id)
#
class ResearchSessionTab < ApplicationRecord
  # Associations
  belongs_to :research_session
  belongs_to :page_visit, primary_key: :id

  # Validations
  validates :url, presence: true
  validates :tab_order, numericality: { greater_than: 0, allow_nil: true }

  # Scopes
  scope :ordered, -> { order(:tab_order) }
  scope :by_domain, ->(domain) { where(domain:) }

  # Instance Methods
  def next_tab
    research_session.research_session_tabs
      .where('tab_order > ?', tab_order)
      .order(:tab_order)
      .first
  end

  def previous_tab
    research_session.research_session_tabs
      .where('tab_order < ?', tab_order)
      .order(tab_order: :desc)
      .first
  end

  def first?
    tab_order == 1
  end

  def last?
    tab_order == research_session.tab_count
  end
end
