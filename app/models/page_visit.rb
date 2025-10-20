# frozen_string_literal: true

class PageVisit < ApplicationRecord
  # Constants
  VALID_CATEGORIES = %w[
    work_coding
    work_code_review
    work_communication
    work_documentation
    learning_video
    learning_reading
    entertainment_video
    entertainment_browsing
    entertainment_short_form
    social_media
    news
    shopping
    reference
    unclassified
  ].freeze

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

  # Category validations
  validates :category, inclusion: { in: VALID_CATEGORIES, allow_nil: true }
  validates :category_confidence, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 1,
    allow_nil: true
  }
  validates :category_method, inclusion: { in: %w[metadata unclassified], allow_nil: true }

  # Metadata validation
  validate :metadata_size_limit

  # Scopes
  scope :recent, -> { order(visited_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id:) }
  scope :valid_data, lambda {
    scope = where.not(visited_at: nil)
      .where.not(url: nil)
      .where('duration_seconds >= 0 OR duration_seconds IS NULL')
      .where('engagement_rate >= 0 AND engagement_rate <= 1 OR engagement_rate IS NULL')
    # Only add scroll_depth_percent check if column exists
    if column_names.include?('scroll_depth_percent')
      scope = scope.where('scroll_depth_percent >= 0 AND scroll_depth_percent <= 100 OR scroll_depth_percent IS NULL')
    end
    scope
  }

  # Category scopes
  scope :by_category, ->(category) { where(category:) }
  scope :categorized, -> { where.not(category: nil).where.not(category: 'unclassified') }
  scope :uncategorized, -> { where(category: [nil, 'unclassified']) }
  scope :work_related, -> { where('category LIKE ?', 'work_%') }
  scope :learning_related, -> { where('category LIKE ?', 'learning_%') }
  scope :entertainment_related, -> { where('category LIKE ?', 'entertainment_%') }

  private

  def metadata_size_limit
    return if metadata.blank?

    # Limit metadata JSON to 50KB (prevents abuse)
    metadata_size = metadata.to_json.bytesize
    max_size = 50.kilobytes

    return unless metadata_size > max_size

    errors.add(:metadata, "is too large (#{metadata_size} bytes, max #{max_size} bytes)")
  end
end
