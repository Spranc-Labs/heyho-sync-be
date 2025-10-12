# frozen_string_literal: true

class DataSyncService < BaseService
  PAGE_VISIT_SCHEMA = {
    type: 'object',
    required: %w[id url title visited_at],
    properties: {
      id: { type: 'string' },
      url: { type: 'string', format: 'uri' },
      title: { type: 'string' },
      visited_at: { type: 'string', format: 'date-time' },
      source_page_visit_id: { type: %w[string null] }
    }
  }.freeze

  TAB_AGGREGATE_SCHEMA = {
    type: 'object',
    required: %w[id page_visit_id total_time_seconds active_time_seconds closed_at],
    properties: {
      id: { type: 'string' },
      page_visit_id: { type: 'string' },
      total_time_seconds: { type: 'integer', minimum: 0 },
      active_time_seconds: { type: 'integer', minimum: 0 },
      scroll_depth_percent: { type: 'integer', minimum: 0, maximum: 100 },
      closed_at: { type: 'string', format: 'date-time' }
    }
  }.freeze

  class << self
    def sync(user:, page_visits: [], tab_aggregates: [])
      new(user:, page_visits:, tab_aggregates:).sync
    end
  end

  def initialize(user:, page_visits: [], tab_aggregates: [])
    super()
    @user = user
    @page_visits = transform_page_visits(Array(page_visits))
    @tab_aggregates = transform_tab_aggregates(Array(tab_aggregates))
  end

  def sync
    return invalid_params_result if user.blank?
    return validation_result unless validate_payload

    save_batch
    success_result(
      data: sync_stats,
      message: 'Data synced successfully'
    )
  rescue StandardError => e
    log_error('Data sync failed', e)
    failure_result(message: 'Data sync failed')
  end

  private

  attr_reader :user, :page_visits, :tab_aggregates

  # Transform extension format to our internal format
  def transform_page_visits(visits)
    visits.map do |visit|
      {
        'id' => visit['id'] || visit['visitId'],
        'url' => visit['url'],
        'title' => visit['title'] || extract_title_from_url(visit['url']),
        'visited_at' => timestamp_to_iso8601(visit['visited_at'] || visit['startedAt']),
        'source_page_visit_id' => visit['source_page_visit_id'] || visit['sourcePageVisitId']
      }.compact
    end
  end

  def transform_tab_aggregates(aggregates)
    aggregates.map do |aggregate|
      {
        'id' => aggregate['id'],
        'page_visit_id' => aggregate['page_visit_id'] || aggregate['pageVisitId'],
        'total_time_seconds' => aggregate['total_time_seconds'] || aggregate['totalTimeSeconds'],
        'active_time_seconds' => aggregate['active_time_seconds'] || aggregate['activeTimeSeconds'],
        'scroll_depth_percent' => aggregate['scroll_depth_percent'] || aggregate['scrollDepthPercent'],
        'closed_at' => timestamp_to_iso8601(aggregate['closed_at'] || aggregate['closedAt'])
      }.compact
    end
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

  def timestamp_to_iso8601(value)
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
    # Deduplicate by ID, keeping the latest version (highest endedAt/timestamp)
    deduplicated_visits = page_visits
                          .group_by { |v| v['id'] }
                          .map do |_id, versions|
      versions.max_by { |v| v['visited_at'] || v['timestamp'] || 0 }
    end

    visits_params = deduplicated_visits.map do |visit|
      {
        id: visit['id'],
        user_id: user.id,
        url: visit['url'],
        title: visit['title'],
        visited_at: visit['visited_at'],
        source_page_visit_id: visit['source_page_visit_id']
      }
    end

    PageVisit.upsert_all(visits_params, unique_by: :id)
  end

  def save_tab_aggregates
    return if tab_aggregates.empty?

    # Deduplicate by ID, keeping the latest version
    deduplicated_aggregates = tab_aggregates
                               .group_by { |a| a['id'] }
                               .map do |_id, versions|
      versions.max_by { |a| a['closed_at'] || 0 }
    end

    aggregates_params = deduplicated_aggregates.map do |aggregate|
      {
        id: aggregate['id'],
        page_visit_id: aggregate['page_visit_id'],
        total_time_seconds: aggregate['total_time_seconds'],
        active_time_seconds: aggregate['active_time_seconds'],
        scroll_depth_percent: aggregate['scroll_depth_percent'],
        closed_at: aggregate['closed_at']
      }
    end

    TabAggregate.upsert_all(aggregates_params, unique_by: :id)
  end

  def sync_stats
    {
      page_visits_synced: page_visits.size,
      tab_aggregates_synced: tab_aggregates.size
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
end
