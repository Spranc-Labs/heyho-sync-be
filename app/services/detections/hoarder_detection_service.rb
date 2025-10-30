# frozen_string_literal: true

module Detections
  # Service to detect "hoarder tabs" using multi-factor age-based scoring
  # New approach (v2):
  # - Primary signal: Tab age (days/weeks old)
  # - Context-aware: Smart domain classification
  # - Multi-factor scoring: Age, inactivity, visit patterns, engagement
  # - Exclusions: Pinned tabs, productivity tools with recent activity
  #
  # Old approach (deprecated but kept for backwards compatibility):
  # - Simple duration + engagement thresholds
  # rubocop:disable Metrics/ClassLength
  class HoarderDetectionService
    # Deprecated constants (kept for backwards compatibility)
    DEFAULT_MIN_OPEN_TIME = 30.minutes
    DEFAULT_MAX_ENGAGEMENT = 0.2

    # New constants for age-based detection
    DEFAULT_LOOKBACK_DAYS = 30 # Look back 30 days for page visits

    # Call with new age-based detection (recommended)
    # @param user [User] User to detect hoarder tabs for
    # @param lookback_days [Integer] How many days back to analyze (default: 30)
    # @param filters [Hash] Optional filters:
    #   - min_score: Minimum hoarder score (default: nil, no filter)
    #   - age_min: Minimum tab age in days (default: nil, no filter)
    #   - domain: Filter to specific domain (default: nil, all domains)
    #   - exclude_domains: Array of domains to exclude (default: nil)
    #   - limit: Maximum results to return (default: nil, all results)
    #   - sort_by: 'hoarder_score' or 'value_rank' (default: 'hoarder_score')
    # @return [Array<Hash>] Hoarder tabs sorted by specified criteria
    def self.call(user, lookback_days: DEFAULT_LOOKBACK_DAYS, filters: {}, **legacy_options)
      # Backwards compatibility: If old parameters provided, use legacy detection
      if legacy_options.key?(:min_open_time) || legacy_options.key?(:max_engagement)
        Rails.logger.warn(
          'HoarderDetectionService: Using deprecated detection method. ' \
          'Please migrate to new age-based detection.'
        )
        return legacy_detection(user, **legacy_options)
      end

      new(user, lookback_days, filters).call
    end

    # Legacy detection for backwards compatibility
    def self.legacy_detection(user, min_open_time: DEFAULT_MIN_OPEN_TIME, max_engagement: DEFAULT_MAX_ENGAGEMENT)
      candidate_visits = PageVisit
        .where(user_id: user.id)
        .where('duration_seconds >= ?', min_open_time.to_i)
        .where('engagement_rate <= ?', max_engagement)
        .where.not(id: ReadingListItem.where(user_id: user.id).where.not(page_visit_id: nil).pluck(:page_visit_id))
        .order(visited_at: :desc)

      unique_visits = candidate_visits.group_by(&:url).transform_values(&:first)

      unique_visits.values.map do |visit|
        {
          page_visit_id: visit.id,
          url: visit.url,
          title: visit.title,
          domain: visit.domain,
          open_time_seconds: visit.duration_seconds,
          engagement_rate: visit.engagement_rate,
          visited_at: visit.visited_at,
          suggested_action: 'save_to_reading_list'
        }
      end
    end

    def initialize(user, lookback_days, filters = {})
      @user = user
      @lookback_days = lookback_days
      @filters = filters
    end

    def call
      detect_hoarder_tabs_v2
    end

    private

    # rubocop:disable Naming/VariableNumber
    def detect_hoarder_tabs_v2
      # Get all page visits within lookback period
      candidate_visits = fetch_candidate_visits

      return [] if candidate_visits.empty?

      # Group visits by URL
      grouped_visits = candidate_visits.group_by(&:url)

      # Analyze each URL group
      hoarder_tabs = grouped_visits.filter_map do |url, visits|
        analyze_url_group(url, visits)
      end

      # Apply filters
      hoarder_tabs = apply_filters(hoarder_tabs)

      # Sort by specified criteria
      hoarder_tabs = apply_sorting(hoarder_tabs)

      # Apply limit if specified
      hoarder_tabs = hoarder_tabs.first(@filters[:limit]) if @filters[:limit]

      hoarder_tabs
    end

    def fetch_candidate_visits
      lookback_date = @lookback_days.days.ago

      # Exclude tabs that we know are closed (have TabAggregate with closed_at)
      closed_visit_ids = TabAggregate
        .where.not(closed_at: nil)
        .pluck(:page_visit_id)

      PageVisit
        .where(user_id: @user.id)
        .where('visited_at >= ?', lookback_date)
        .where.not(id: already_saved_visit_ids)
        .where.not(id: closed_visit_ids)
        .order(:url, :visited_at)
    end

    def analyze_url_group(url, visits)
      # Calculate tab metadata
      tab_metadata = Insights::Calculators::TabAgeCalculator.calculate(visits)
      return nil if tab_metadata.nil?

      # Analyze domain context
      domain_context = Insights::Analyzers::DomainContextAnalyzer.analyze(
        user: @user,
        domain: tab_metadata[:domain],
        url:,
        tab_metadata:
      )

      # Calculate hoarder score
      score_result = Insights::Analyzers::HoarderScorer.calculate(
        tab_metadata:,
        domain_context:
      )

      # Only return if flagged as hoarder
      return nil unless score_result[:is_hoarder]

      # Build hoarder tab result
      build_hoarder_tab_v2(tab_metadata, score_result)
    end
    # rubocop:enable Naming/VariableNumber

    # rubocop:disable Naming/VariableNumber
    def build_hoarder_tab_v2(tab_metadata, score_result)
      most_recent_visit = tab_metadata[:most_recent_visit]

      {
        # Core identification
        page_visit_id: most_recent_visit.id,
        url: tab_metadata[:url],
        title: tab_metadata[:title],
        domain: tab_metadata[:domain],

        # Temporal data
        visited_at: tab_metadata[:first_visited_at],
        last_activity_at: tab_metadata[:last_visited_at],
        tab_age_days: tab_metadata[:tab_age_days],
        days_since_last_activity: tab_metadata[:days_since_last_activity],

        # Activity metrics
        visit_count: tab_metadata[:visit_count],
        total_duration_seconds: tab_metadata[:total_duration_seconds],
        engagement_rate: tab_metadata[:average_engagement_rate],

        # Hoarder scoring
        hoarder_score: score_result[:total_score],
        confidence_level: score_result[:confidence_level],
        reason: score_result[:reason],
        score_breakdown: score_result[:score_breakdown],

        # Behavioral flags
        is_likely_still_open: tab_metadata[:is_likely_still_open],
        is_single_visit: tab_metadata[:is_single_visit],

        # Preview metadata (image, favicon, description for link preview cards)
        preview: extract_preview_metadata(most_recent_visit),

        # Suggested action
        suggested_action: suggest_action(score_result)
      }
    end
    # rubocop:enable Naming/VariableNumber

    def extract_preview_metadata(visit)
      return nil unless visit&.metadata

      # Extract preview metadata if it exists
      preview = visit.metadata['preview'] || {}

      # Only return preview if it has at least one useful field
      has_useful_data = preview['image'].present? ||
                        preview['favicon'].present? ||
                        preview['description'].present?

      return nil unless has_useful_data

      {
        image: preview['image'],
        favicon: preview['favicon'],
        description: preview['description'],
        site_name: preview['siteName'],
        author: preview['author']
      }.compact # Remove nil values
    end

    def suggest_action(score_result)
      case score_result[:confidence_level]
      when :high
        'save_to_reading_list_or_close'
      when :medium
        'save_to_reading_list'
      else
        'review'
      end
    end

    def apply_filters(tabs)
      filtered = tabs

      # Filter by minimum hoarder score
      filtered = filtered.select { |tab| tab[:hoarder_score] >= @filters[:min_score] } if @filters[:min_score]

      # Filter by minimum tab age
      filtered = filtered.select { |tab| tab[:tab_age_days] >= @filters[:age_min] } if @filters[:age_min]

      # Filter by specific domain
      filtered = filtered.select { |tab| tab[:domain] == @filters[:domain] } if @filters[:domain]

      # Exclude specific domains
      if @filters[:exclude_domains]
        exclude_list = Array(@filters[:exclude_domains])
        filtered = filtered.reject { |tab| exclude_list.include?(tab[:domain]) }
      end

      filtered
    end

    def apply_sorting(tabs)
      sort_by = @filters[:sort_by] || 'hoarder_score'

      case sort_by.to_s
      when 'value_rank'
        # Apply value-based ranking
        Insights::Analyzers::ValueRanker.rank(tabs)
      when 'age'
        tabs.sort_by { |tab| -tab[:tab_age_days] }
      else
        # Default to hoarder score (includes 'hoarder_score' and any unknown values)
        tabs.sort_by { |tab| -tab[:hoarder_score] }
      end
    end

    def already_saved_visit_ids
      # Get page_visit_ids that are already in the reading list
      ReadingListItem
        .where(user_id: @user.id)
        .where.not(page_visit_id: nil)
        .pluck(:page_visit_id)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
