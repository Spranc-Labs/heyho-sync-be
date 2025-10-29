# frozen_string_literal: true

module DataProcessing
  # rubocop:disable Metrics/ClassLength
  # This service comprehensively validates all page visit and tab aggregate fields.
  # The class is intentionally long to keep all validation logic in one cohesive unit.
  class DataValidationService
  # Constants
  MAX_URL_LENGTH = 2048
  MAX_TITLE_LENGTH = 500
  MAX_DOMAIN_LENGTH = 253
  MIN_DURATION = 0
  MAX_DURATION = 86_400 # 24 hours in seconds
  MIN_SCROLL_DEPTH = 0
  MAX_SCROLL_DEPTH = 100
  MIN_ENGAGEMENT_RATE = 0.0
  MAX_ENGAGEMENT_RATE = 1.0

  VALID_URL_SCHEMES = %w[http https].freeze

  # Result object
  Result = Struct.new(:valid?, :errors, :warnings, keyword_init: true) do
    def invalid? = !valid?
    def errors? = errors.any?
    def warnings? = warnings.any?
  end

  def self.validate_page_visit(data)
    new.validate_page_visit(data)
  end

  def self.validate_tab_aggregate(data)
    new.validate_tab_aggregate(data)
  end

  def initialize
    @errors = []
    @warnings = []
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # This method intentionally validates multiple fields comprehensively
  def validate_page_visit(data)
    validate_required_fields(data, %w[id url visited_at])
    validate_url(data['url'], 'url') if data['url']
    validate_string_length(data['title'], 'title', MAX_TITLE_LENGTH) if data['title']
    validate_string_length(data['domain'], 'domain', MAX_DOMAIN_LENGTH) if data['domain']
    validate_timestamp(data['visited_at'], 'visited_at') if data['visited_at']
    validate_duration(data['duration_seconds'], 'duration_seconds') if data['duration_seconds']
    validate_duration(data['active_duration_seconds'], 'active_duration_seconds') if data['active_duration_seconds']
    validate_engagement_rate(data['engagement_rate']) if data['engagement_rate']
    validate_scroll_depth(data['scroll_depth_percent']) if data['scroll_depth_percent']

    # Category validation
    validate_category(data['category']) if data['category']
    validate_category_confidence(data['category_confidence']) if data['category_confidence']
    validate_category_method(data['category_method']) if data['category_method']

    # Metadata size validation
    validate_metadata_size(data['metadata']) if data['metadata']

    build_result
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # This method intentionally validates multiple fields comprehensively
  def validate_tab_aggregate(data)
    validate_required_fields(data, %w[id])
    # closed_at is optional - open tabs don't have it yet
    # current_url is optional - validate only if present
    validate_url(data['current_url'], 'current_url') if data['current_url']
    validate_string_length(data['title'], 'title', MAX_TITLE_LENGTH) if data['title']
    validate_string_length(data['domain'], 'domain', MAX_DOMAIN_LENGTH) if data['domain']
    validate_timestamp(data['opened_at'], 'opened_at') if data['opened_at']
    validate_timestamp(data['closed_at'], 'closed_at') if data['closed_at']
    validate_duration(data['duration_seconds'], 'duration_seconds') if data['duration_seconds']
    validate_duration(data['active_duration_seconds'], 'active_duration_seconds') if data['active_duration_seconds']
    validate_scroll_depth(data['scroll_depth_percent']) if data['scroll_depth_percent']

    # Validate time consistency
    validate_time_order(data) if data['opened_at'] && data['closed_at']

    build_result
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  private

  def validate_required_fields(data, fields)
    fields.each do |field|
      next if data[field].present?

      add_error(field, 'is required but missing')
    end
  end

  def validate_url(url, field_name)
    return add_error(field_name, 'cannot be blank') if url.blank?

    if url.length > MAX_URL_LENGTH
      return add_error(field_name, "exceeds maximum length of #{MAX_URL_LENGTH} characters")
    end

    begin
      uri = URI.parse(url)

      unless VALID_URL_SCHEMES.include?(uri.scheme&.downcase)
        return add_error(field_name, 'must use http or https scheme')
      end

      add_warning(field_name, 'missing domain') if uri.host.blank?
    rescue URI::InvalidURIError => e
      add_error(field_name, "is not a valid URL: #{e.message}")
    end
  end

  def validate_string_length(value, field_name, max_length)
    return if value.blank?

    return unless value.is_a?(String)

    return unless value.length > max_length

    add_warning(field_name, "exceeds recommended length of #{max_length} characters (will be truncated)")
  end

  def validate_timestamp(value, field_name)
    return if value.blank?

    Time.iso8601(value)
  rescue ArgumentError
    add_error(field_name, 'is not a valid ISO8601 timestamp')
  end

  def validate_duration(value, field_name)
    return if value.blank?

    return add_error(field_name, 'must be a number') unless value.is_a?(Numeric)

    return add_error(field_name, 'cannot be negative') if value.negative?

    return unless value > MAX_DURATION

    add_warning(field_name, "exceeds maximum expected duration of #{MAX_DURATION} seconds")
  end

  def validate_scroll_depth(value)
    return if value.blank?

    return add_error('scroll_depth_percent', 'must be a number') unless value.is_a?(Numeric)

    return add_error('scroll_depth_percent', "cannot be less than #{MIN_SCROLL_DEPTH}") if value < MIN_SCROLL_DEPTH

    return unless value > MAX_SCROLL_DEPTH

    add_error('scroll_depth_percent', "cannot exceed #{MAX_SCROLL_DEPTH}")
  end

  def validate_engagement_rate(value)
    return if value.blank?

    return add_error('engagement_rate', 'must be a number') unless value.is_a?(Numeric)

    return add_error('engagement_rate', "cannot be less than #{MIN_ENGAGEMENT_RATE}") if value < MIN_ENGAGEMENT_RATE

    return unless value > MAX_ENGAGEMENT_RATE

    add_error('engagement_rate', "cannot exceed #{MAX_ENGAGEMENT_RATE}")
  end

  def validate_time_order(data)
    opened = Time.iso8601(data['opened_at'])
    closed = Time.iso8601(data['closed_at'])

    return unless opened > closed

    add_error('closed_at', 'cannot be before opened_at')
  rescue ArgumentError
    # Timestamp validation will catch this
    nil
  end

  def validate_category(value)
    return if value.blank?

    return if PageVisit::VALID_CATEGORIES.include?(value)

    add_error('category', "must be one of: #{PageVisit::VALID_CATEGORIES.join(", ")}")
  end

  def validate_category_confidence(value)
    return if value.blank?

    return add_error('category_confidence', 'must be a number') unless value.is_a?(Numeric)

    return add_error('category_confidence', 'cannot be less than 0') if value.negative?

    return unless value > 1

    add_error('category_confidence', 'cannot exceed 1')
  end

  def validate_category_method(value)
    return if value.blank?

    valid_methods = %w[metadata unclassified]
    return if valid_methods.include?(value)

    add_warning('category_method', "unknown method '#{value}' (expected: #{valid_methods.join(", ")})")
  end

  def validate_metadata_size(value)
    return if value.blank?

    max_size = 50.kilobytes
    metadata_size = value.to_json.bytesize

    return unless metadata_size > max_size

    add_error('metadata', "is too large (#{metadata_size} bytes, max #{max_size} bytes)")
  end

  def add_error(field, message)
    @errors << { field:, message: }
  end

  def add_warning(field, message)
    @warnings << { field:, message: }
  end

  def build_result
    Result.new(
      valid?: @errors.empty?,
      errors: @errors,
      warnings: @warnings
    )
  end
  end
end
# rubocop:enable Metrics/ClassLength
