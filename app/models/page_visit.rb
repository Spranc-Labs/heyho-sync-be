# frozen_string_literal: true

class PageVisit < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :tab_aggregates, dependent: :destroy
  belongs_to :source_page_visit, class_name: 'PageVisit', optional: true
  has_many :child_page_visits, class_name: 'PageVisit', foreign_key: :source_page_visit_id, dependent: :nullify,
                               inverse_of: :source_page_visit

  # Validations
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :title, presence: true
  validates :visited_at, presence: true

  # Scopes
  scope :recent, -> { order(visited_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id:) }
end
