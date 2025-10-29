# frozen_string_literal: true

module DataProcessing
  # rubocop:disable Metrics/ClassLength
  # This service handles complex data transformation from browser extension format to our internal format.
  # Breaking it into multiple classes would reduce cohesion. All methods are focused and under 20 lines.
  class DataSyncService < BaseService
  PAGE_VISIT_SCHEMA = {
    type: 'object',
    required: %w[id url title visited_at],
    properties: {
      id: { type: 'string' },
      url: { type: 'string', format: 'uri' },
      title: { type: 'string' },
      visited_at: { type: 'string', format: 'date-time' },
      opened_at: { type: %w[string null], format: 'date-time' }, # When tab was actually opened (not just activated)
      source_page_visit_id: { type: %w[string null] },
      # Categorization fields (optional)
      category: { type: %w[string null] },
      categoryConfidence: { type: %w[number null] },
      categoryMethod: { type: %w[string null] },
      # Metadata (optional)
      metadata: { type: %w[object null] }
    }
  }.freeze

  TAB_AGGREGATE_SCHEMA = {
    type: 'object',
    required: %w[id page_visit_id total_time_seconds active_time_seconds],
    properties: {
      id: { type: 'string' },
      page_visit_id: { type: 'string' },
      total_time_seconds: { type: 'integer', minimum: 0 },
      active_time_seconds: { type: 'integer', minimum: 0 },
      scroll_depth_percent: { type: 'integer', minimum: 0, maximum: 100 },
      closed_at: { type: %w[string null], format: 'date-time' }
    }
  }.freeze

  # Configuration
  MAX_BATCH_SIZE = 1000

  class << self
    def sync(user:, page_visits: [], tab_aggregates: [], client_info: {})
      new(user:, page_visits:, tab_aggregates:, client_info:).sync
    end
  end

  def initialize(user:, page_visits: [], tab_aggregates: [], client_info: {})
    super()
    @user = user
    @client_info = client_info || {}
    @raw_page_visits = Array(page_visits)
    @raw_tab_aggregates = Array(tab_aggregates)
    @validation_service = DataProcessing::DataValidationService.new
    @sanitization_service = DataProcessing::DataSanitizationService.new
    @rejected_records = []
    @page_visits = []
    @tab_aggregates = []
    @sync_log = nil
  end

  def sync
    return invalid_params_result if user.blank?
    return batch_size_exceeded_result if raw_batch_size_exceeded?

    create_sync_log
    process_and_validate_records
    return validation_result if all_records_rejected?

    save_batch if valid_records?
    complete_sync_log
    success_result(
      data: sync_stats,
      message: build_success_message
    )
  rescue StandardError => e
    log_error('Data sync failed', e)
    fail_sync_log(e.message)
    failure_result(message: 'Data sync failed')
  end

  private

  attr_reader :user, :page_visits, :tab_aggregates, :raw_page_visits, :raw_tab_aggregates,
              :client_info, :sync_log, :rejected_records, :validation_service, :sanitization_service

  # Validation and processing workflow
  def process_and_validate_records
    process_page_visits
    process_tab_aggregates
  end

  def process_page_visits
    raw_page_visits.each_with_index do |raw_visit, index|
      visit = transform_and_validate_page_visit(raw_visit, index)
      @page_visits << visit if visit
    end
  end

  def process_tab_aggregates
    transformed_aggregates = transform_tab_aggregates(raw_tab_aggregates, raw_page_visits)
    transformed_aggregates.each_with_index do |aggregate, index|
      validated = validate_and_sanitize_tab_aggregate(aggregate, index)
      @tab_aggregates << validated if validated
    end
  end

  def transform_and_validate_page_visit(raw_visit, index)
    # Transform to internal format
    visit = build_page_visit_hash(raw_visit)

    # Validate
    validation_result = validation_service.validate_page_visit(visit)

    if validation_result.invalid?
      record_validation_errors(visit['id'], 'page_visit', index, validation_result.errors)
      return nil
    end

    # Sanitize
    sanitized = sanitization_service.sanitize_page_visit(visit)

    # Log warnings if any
    log_validation_warnings(visit['id'], 'page_visit', validation_result.warnings) if validation_result.warnings?

    sanitized
  end

  def validate_and_sanitize_tab_aggregate(aggregate, index)
    # Validate
    validation_result = validation_service.validate_tab_aggregate(aggregate)

    if validation_result.invalid?
      record_validation_errors(aggregate['id'], 'tab_aggregate', index, validation_result.errors)
      return nil
    end

    # Sanitize
    sanitized = sanitization_service.sanitize_tab_aggregate(aggregate)

    # Log warnings if any
    if validation_result.warnings?
      log_validation_warnings(aggregate['id'], 'tab_aggregate',
                              validation_result.warnings)
    end

    sanitized
  end

  def record_validation_errors(record_id, record_type, index, errors)
    @rejected_records << { id: record_id, type: record_type, index:, errors: }

    errors.each do |error|
      sync_log.add_validation_error(
        record_id:,
        record_type:,
        field: error[:field],
        message: error[:message],
        value: error[:value]
      )
    end
  end

  def log_validation_warnings(record_id, record_type, warnings)
    warnings.each do |warning|
      Rails.logger.warn(
        "Validation warning for #{record_type} #{record_id}: #{warning[:field]} - #{warning[:message]}"
      )
    end
  end

  def all_records_rejected?
    page_visits.empty? && tab_aggregates.empty? && rejected_records.any?
  end

  def valid_records?
    page_visits.any? || tab_aggregates.any?
  end

  def build_success_message
    if rejected_records.any?
      "Data synced with #{rejected_records.size} record(s) rejected due to validation errors"
    else
      'Data synced successfully'
    end
  end

  # Transform extension format to our internal format
  def transform_page_visits(visits)
    visits.map { |visit| build_page_visit_hash(visit) }
  end

  def build_page_visit_hash(visit)
    {
      'id' => get_value(visit, 'id', 'visitId'),
      'url' => visit['url'],
      'title' => visit['title'] || extract_title_from_url(visit['url']),
      'visited_at' => timestamp_to_iso_8601(get_value(visit, 'visited_at', 'startedAt')),
      'opened_at' => timestamp_to_iso_8601(get_value(visit, 'opened_at', 'openedAt')), # When tab was actually opened
      'source_page_visit_id' => get_value(visit, 'source_page_visit_id', 'sourcePageVisitId'),
      'tab_id' => visit['tabId'],
      'domain' => visit['domain'],
      'duration_seconds' => get_value(visit, 'durationSeconds', 'duration_seconds'),
      'active_duration_seconds' => (visit['activeDuration'] || 0) / 1000, # Convert ms to seconds
      'engagement_rate' => get_value(visit, 'engagementRate', 'engagement_rate'),
      'idle_periods' => get_value(visit, 'idlePeriods', 'idle_periods'),
      'last_heartbeat' => get_value(visit, 'lastHeartbeat', 'last_heartbeat'),
      'anonymous_client_id' => get_value(visit, 'anonymousClientId', 'anonymous_client_id'),
      # Categorization fields
      'category' => visit['category'],
      'category_confidence' => visit['categoryConfidence'],
      'category_method' => visit['categoryMethod'],
      # Metadata (sanitize before storing)
      'metadata' => sanitize_metadata(visit['metadata'])
    }
  end

  def get_value(hash, *keys)
    keys.each do |key|
      value = hash[key]
      return value if value
    end
    nil
  end

  def transform_tab_aggregates(aggregates, page_visits)
    tab_to_page_visit = build_tab_to_page_visit_map(page_visits)
    aggregates.filter_map { |aggregate| transform_single_aggregate(aggregate, tab_to_page_visit) }.compact
  end

  def build_tab_to_page_visit_map(page_visits)
    page_visits.each_with_object({}) do |visit, map|
      tab_id = visit['tabId']
      visit_id = visit['id'] || visit['visitId']
      next unless tab_id && visit_id

      map[tab_id] ||= visit_id # Keep the first (earliest) page visit for each tab
    end
  end

  def transform_single_aggregate(aggregate, tab_to_page_visit)
    if browser_extension_format?(aggregate)
      transform_browser_extension_aggregate(aggregate, tab_to_page_visit)
    else
      transform_api_aggregate(aggregate)
    end
  end

  def browser_extension_format?(aggregate)
    # Check for both camelCase (old format) and snake_case (new format)
    has_tab_id = aggregate['tabId'].present?
    has_start_time = aggregate['startTime'].present? || aggregate['start_time'].present?
    has_tab_id && has_start_time
  end

  def transform_browser_extension_aggregate(aggregate, tab_to_page_visit)
    tab_id = aggregate['tabId']
    page_visit_id = tab_to_page_visit[tab_id]

    return log_and_skip('no matching page visit found', tab_id) unless page_visit_id

    # Support both camelCase (old) and snake_case (new) formats
    start_time = aggregate['startTime'] || aggregate['start_time']
    last_active = aggregate['lastActiveTime'] || aggregate['last_active_time'] || start_time
    calculated_seconds = calculate_duration_seconds(start_time, last_active, tab_id)

    return nil unless calculated_seconds

    build_aggregate_hash(
      aggregate:,
      page_visit_id:,
      calculated_seconds:,
      last_active:,
      start_time:,
      tab_id:
    )
  end

  def calculate_duration_seconds(start_time, last_active, tab_id)
    calculated_duration_ms = last_active - start_time
    calculated_seconds = (calculated_duration_ms / 1000.0).to_i
    max_seconds = 365 * 24 * 3600 # 1 year

    if calculated_seconds > max_seconds || calculated_seconds.negative?
      log_invalid_duration(calculated_seconds, tab_id)
      return nil
    end

    calculated_seconds
  end

  # rubocop:disable Metrics/ParameterLists
  # Keyword arguments improve readability for this data transformation method
  def build_aggregate_hash(aggregate:, page_visit_id:, calculated_seconds:, last_active:, start_time:, tab_id:)
    # rubocop:enable Metrics/ParameterLists
    # Determine closed_at: only set if aggregate explicitly has closedAt/closed_at or isOpen/is_open=false
    # Otherwise leave as nil (tab might still be open, we don't know)
    closed_at_value = aggregate['closedAt'] || aggregate['closed_at']
    is_open_value = aggregate['isOpen'] || aggregate['is_open']

    closed_at = if closed_at_value
                  timestamp_to_iso_8601(closed_at_value)
                elsif is_open_value == false
                  timestamp_to_iso_8601(closed_at_value || last_active)
                end

    {
      'id' => aggregate['id'] || "agg_#{start_time}_#{tab_id}",
      'page_visit_id' => page_visit_id,
      'total_time_seconds' => calculated_seconds,
      'active_time_seconds' => calculated_seconds,
      'scroll_depth_percent' => aggregate['scroll_depth_percent'] || 0,
      'closed_at' => closed_at,
      'domain_durations' => aggregate['domainDurations'] || aggregate['domain_durations'],
      'page_count' => validate_page_count(aggregate['pageCount'] || aggregate['page_count'], tab_id),
      'current_url' => aggregate['currentUrl'] || aggregate['current_url'] || aggregate['url'],
      'current_domain' => aggregate['currentDomain'] || aggregate['current_domain'] || aggregate['domain'],
      'statistics' => aggregate['statistics']
    }
  end

  def validate_page_count(page_count, tab_id)
    return nil unless page_count

    max_bigint = 9_223_372_036_854_775_807
    if page_count.to_i > max_bigint
      Rails.logger.warn "Capping invalid page_count #{page_count} to nil for tabId #{tab_id}"
      return nil
    end

    page_count
  end

  def transform_api_aggregate(aggregate)
    {
      'id' => aggregate['id'],
      'page_visit_id' => aggregate['page_visit_id'] || aggregate['pageVisitId'],
      'total_time_seconds' => aggregate['total_time_seconds'] || aggregate['totalTimeSeconds'],
      'active_time_seconds' => aggregate['active_time_seconds'] || aggregate['activeTimeSeconds'],
      'scroll_depth_percent' => aggregate['scroll_depth_percent'] || aggregate['scrollDepthPercent'],
      'closed_at' => timestamp_to_iso_8601(aggregate['closed_at'] || aggregate['closedAt'])
    }
  end

  def log_and_skip(reason, tab_id)
    Rails.logger.warn "Skipping tab aggregate for tabId #{tab_id}: #{reason}"
    nil
  end

  def log_invalid_duration(calculated_seconds, tab_id)
    days = calculated_seconds / 86_400.0
    Rails.logger.warn "Skipping tab aggregate with invalid duration: #{calculated_seconds}s " \
                      "(#{days} days) for tabId #{tab_id}"
  end

  def extract_title_from_url(url)
    return 'Unknown' if url.blank?

    # Handle special URLs
    return 'Firefox Debugging' if url.start_with?('about:')
    return 'New Tab' if url == 'about:newtab'

    # Extract domain as fallback title
    uri = URI.parse(url)
    uri.host&.gsub('www.', '')&.capitalize || 'Unknown'
  rescue URI::InvalidURIError
    'Unknown'
  end

  def timestamp_to_iso_8601(value)
    return value if value.blank?
    return value if value.is_a?(String) && value.match?(/^\d{4}-\d{2}-\d{2}/)

    # Convert millisecond timestamp to ISO8601
    Time.at(value.to_i / 1000.0).utc.iso8601
  rescue StandardError
    nil
  end

  def validate_payload
    @validation_errors = []

    page_visits.each_with_index do |visit, index|
      validate_record(visit, PAGE_VISIT_SCHEMA, "pageVisits[#{index}]")
    end

    tab_aggregates.each_with_index do |aggregate, index|
      validate_record(aggregate, TAB_AGGREGATE_SCHEMA, "tabAggregates[#{index}]")
    end

    @validation_errors.empty?
  end

  def validate_record(record, schema, path)
    schemer = JSONSchemer.schema(schema)
    errors = schemer.validate(record).to_a

    errors.each do |error|
      @validation_errors << {
        path:,
        field: error['data_pointer'],
        error: error['error']
      }
    end
  end

  def save_batch
    ActiveRecord::Base.transaction do
      save_page_visits if page_visits.any?
      save_tab_aggregates if tab_aggregates.any?
    end
  end

  def save_page_visits
    deduplicated_visits = deduplicate_by_id(page_visits, sort_by: 'visited_at')
    visits_params = deduplicated_visits.map { |visit| build_page_visit_params(visit) }

    # Use smart merge: update only if new data is more recent or more complete
    # rubocop:disable Rails/SkipsModelValidations
    PageVisit.upsert_all(
      visits_params,
      unique_by: :id,
      update_only: %i[
        url title visited_at opened_at source_page_visit_id domain
        duration_seconds active_duration_seconds engagement_rate
        idle_periods last_heartbeat anonymous_client_id
        category category_confidence category_method metadata
      ]
    )
    # rubocop:enable Rails/SkipsModelValidations
  end

  def build_page_visit_params(visit)
    {
      id: visit['id'],
      user_id: user.id,
      url: visit['url'],
      title: visit['title'],
      visited_at: visit['visited_at'],
      opened_at: visit['opened_at'], # When tab was actually opened (from browser)
      source_page_visit_id: visit['source_page_visit_id'],
      tab_id: visit['tab_id'],
      domain: visit['domain'],
      duration_seconds: visit['duration_seconds'],
      active_duration_seconds: visit['active_duration_seconds'],
      engagement_rate: visit['engagement_rate'],
      idle_periods: visit['idle_periods'],
      last_heartbeat: visit['last_heartbeat'],
      anonymous_client_id: visit['anonymous_client_id'],
      category: visit['category'],
      category_confidence: visit['category_confidence'],
      category_method: visit['category_method'],
      metadata: sanitize_metadata(visit['metadata'])
    }
  end

  def save_tab_aggregates
    return if tab_aggregates.empty?

    deduplicated_aggregates = deduplicate_by_id(tab_aggregates, sort_by: 'closed_at')
    aggregates_params = deduplicated_aggregates.map { |aggregate| build_tab_aggregate_params(aggregate) }

    # Use smart merge: update only if new data is more recent or more complete
    # rubocop:disable Rails/SkipsModelValidations
    TabAggregate.upsert_all(
      aggregates_params,
      unique_by: :id,
      update_only: %i[
        page_visit_id total_time_seconds active_time_seconds
        scroll_depth_percent closed_at domain_durations page_count
        current_url current_domain statistics
      ]
    )
    # rubocop:enable Rails/SkipsModelValidations
  end

  def build_tab_aggregate_params(aggregate)
    {
      id: aggregate['id'],
      page_visit_id: aggregate['page_visit_id'],
      total_time_seconds: aggregate['total_time_seconds'],
      active_time_seconds: aggregate['active_time_seconds'],
      scroll_depth_percent: aggregate['scroll_depth_percent'],
      closed_at: aggregate['closed_at'],
      domain_durations: aggregate['domain_durations'],
      page_count: aggregate['page_count'],
      current_url: aggregate['current_url'],
      current_domain: aggregate['current_domain'],
      statistics: aggregate['statistics']
    }
  end

  def deduplicate_by_id(records, sort_by:)
    records
      .group_by { |record| record['id'] }
      .map { |_id, versions| resolve_conflict(versions, sort_by) }
  end

  # Smart conflict resolution: merge multiple versions of same record
  def resolve_conflict(versions, sort_by)
    return versions.first if versions.size == 1

    # Start with the most recent version
    base = versions.max_by { |v| v[sort_by] || 0 }

    # Merge in non-nil values from other versions (prefer non-nil over nil)
    versions.each do |version|
      next if version == base

      merge_version_into_base(base, version)
    end

    base
  end

  # Duration fields that should use max value during conflict resolution
  DURATION_FIELDS = %w[
    duration_seconds active_duration_seconds
    total_time_seconds active_time_seconds
  ].freeze

  def merge_version_into_base(base, version)
    version.each do |key, value|
      next if value.nil?

      # Update if base value is nil and new value is not
      if base[key].nil?
        base[key] = value
        next
      end

      # For duration fields, prefer higher values (more complete data)
      base[key] = [base[key].to_i, value.to_i].max if DURATION_FIELDS.include?(key)

      # For scroll depth, prefer higher values
      base[key] = [base[key].to_i, value.to_i].max if key == 'scroll_depth_percent'
    end
  end

  def sync_stats
    {
      page_visits_synced: page_visits.size,
      tab_aggregates_synced: tab_aggregates.size,
      rejected_records_count: rejected_records.size,
      data_quality_score: sync_log&.data_quality_score,
      validation_errors: sync_log&.validation_errors || []
    }
  end

  def invalid_params_result
    failure_result(message: 'User is required')
  end

  def validation_result
    failure_result(
      message: 'Validation failed for one or more records',
      errors: @validation_errors
    )
  end

  def raw_batch_size_exceeded?
    total_records = raw_page_visits.size + raw_tab_aggregates.size
    total_records > MAX_BATCH_SIZE
  end

  def batch_size_exceeded_result
    total = raw_page_visits.size + raw_tab_aggregates.size
    failure_result(
      message: "Batch size exceeded. Maximum #{MAX_BATCH_SIZE} records allowed, got #{total}"
    )
  end

  # SyncLog tracking methods
  def create_sync_log
    @sync_log = SyncLog.create!(
      user:,
      synced_at: Time.current,
      status: 'processing',
      client_info:,
      page_visits_synced: 0,
      tab_aggregates_synced: 0
    )
  end

  def complete_sync_log
    return unless sync_log

    sync_log.save!
    sync_log.update!(
      status: 'completed',
      page_visits_synced: page_visits.size,
      tab_aggregates_synced: tab_aggregates.size
    )
  end

  def fail_sync_log(error_message)
    return unless sync_log

    sync_log.mark_failed!([error_message])
  end

  # Sanitize metadata to prevent XSS and limit size
  def sanitize_metadata(metadata)
    return {} if metadata.blank?

    # Ensure metadata is a hash
    metadata = {} unless metadata.is_a?(Hash)

    # Remove potentially dangerous keys
    dangerous_keys = %w[__proto__ constructor prototype]
    metadata = metadata.reject { |key, _| dangerous_keys.include?(key.to_s) }

    # Truncate strings to prevent abuse (max 2000 chars per string)
    deep_truncate_strings(metadata, max_length: 2000)
  end

  def deep_truncate_strings(obj, max_length:)
    case obj
    when Hash
      obj.transform_values { |v| deep_truncate_strings(v, max_length:) }
    when Array
      obj.map { |v| deep_truncate_strings(v, max_length:) }
    when String
      obj.length > max_length ? "#{obj[0...max_length]}..." : obj
    else
      obj
    end
  end
  end
end
# rubocop:enable Metrics/ClassLength
