# frozen_string_literal: true

# Service to detect "serial openers" - resources repeatedly opened but never finished
# Criteria:
# - Visit count >= 3 (default)
# - Total engagement time < 5 minutes (default)
# - Not already in reading list
# - Supports date range filtering
class SerialOpenerDetectionService
  DEFAULT_MIN_VISITS = 3
  DEFAULT_MAX_TOTAL_ENGAGEMENT = 5.minutes
  MIN_VISITS_PER_DAY = 0.43 # ~3 visits per week

  def self.call(user, min_visits: DEFAULT_MIN_VISITS, max_total_engagement: DEFAULT_MAX_TOTAL_ENGAGEMENT,
                start_date: nil, end_date: nil, days_in_period: nil)
    new(user, min_visits, max_total_engagement, start_date, end_date, days_in_period).call
  end

  def initialize(user, min_visits, max_total_engagement, start_date = nil, end_date = nil, days_in_period = nil)
    @user = user
    @min_visits = min_visits
    @max_total_engagement = max_total_engagement
    @start_date = start_date
    @end_date = end_date
    @days_in_period = days_in_period
  end

  def call
    detect_serial_openers
  end

  private

  def detect_serial_openers
    # Group page visits by NORMALIZED URL to find repeatedly visited resources
    all_visits = fetch_visits

    # Group by normalized URL instead of raw URL
    grouped_visits = all_visits.group_by { |visit| normalize_url(visit.url) }

    serial_openers = grouped_visits.filter_map do |normalized_url, visits|
      # Use visits-per-day threshold if days_in_period provided, otherwise use absolute count
      if @days_in_period
        visits_per_day = visits.size.to_f / @days_in_period
        next if visits_per_day < MIN_VISITS_PER_DAY
      elsif visits.size < @min_visits
        next
      end

      total_duration = visits.sum(&:duration_seconds)
      next if total_duration >= @max_total_engagement.to_i

      build_serial_opener(normalized_url, visits)
    end

    serial_openers.sort_by { |so| -so[:visit_count] }
  end

  def fetch_visits
    query = PageVisit
      .where(user_id: @user.id)
      .where.not(id: already_saved_visit_ids)

    # Apply date range filter if provided
    if @start_date.present? && @end_date.present?
      query = query.where('visited_at >= ? AND visited_at <= ?', @start_date, @end_date)
    end

    query.select(:id, :url, :title, :domain, :duration_seconds, :engagement_rate, :visited_at, :category)
  end

  def already_saved_visit_ids
    # Get page_visit_ids that are already in the reading list
    ReadingListItem
      .where(user_id: @user.id)
      .where.not(page_visit_id: nil)
      .pluck(:page_visit_id)
  end

  def build_serial_opener(normalized_url, visits)
    most_recent = visits.max_by(&:visited_at)
    first_visit = visits.min_by(&:visited_at)
    total_duration = visits.sum(&:duration_seconds)
    avg_engagement = visits.filter_map(&:engagement_rate).sum / visits.size.to_f

    # Get unique raw URLs to show variations
    raw_urls = visits.map(&:url).uniq

    {
      page_visit_id: most_recent.id,
      url: most_recent.url, # Use most recent actual URL
      normalized_url:,
      url_variations_count: raw_urls.size,
      title: most_recent.title,
      domain: most_recent.domain,
      category: most_recent.category,
      visit_count: visits.size,
      total_engagement_seconds: total_duration,
      avg_engagement_per_visit: total_duration.to_f / visits.size,
      first_visit_at: first_visit.visited_at,
      last_visit_at: most_recent.visited_at,
      engagement_rate: avg_engagement,
      suggested_action: 'save_to_reading_list'
    }
  end

  # Normalize URLs to group similar resources
  # Removes query parameters and fragments for certain domains
  def normalize_url(url)
    return url if url.blank?

    uri = URI.parse(url)
    host = uri.host&.downcase || ''

    # Notion: Remove view parameters and fragments
    # Example: https://notion.so/page-abc123?v=view1 -> https://notion.so/page-abc123
    if host.include?('notion.so') || host.include?('notion.site')
      base_path = uri.path.split('?').first
      return "#{uri.scheme}://#{host}#{base_path}"
    end

    # GitHub: Keep path but remove query params and fragments
    # Example: https://github.com/user/repo/pull/123?tab=files -> https://github.com/user/repo/pull/123
    return "#{uri.scheme}://#{host}#{uri.path}" if host.include?('github.com')

    # Gmail: Normalize to domain only (inbox views are the same)
    # Example: https://mail.google.com/mail/u/0/#inbox -> https://mail.google.com
    return "#{uri.scheme}://#{host}" if host.include?('mail.google.com')

    # Social media: Remove query params
    if host.include?('twitter.com') || host.include?('x.com') ||
       host.include?('linkedin.com') || host.include?('facebook.com')
      return "#{uri.scheme}://#{host}#{uri.path}"
    end

    # For other domains, return the full URL without fragments
    "#{uri.scheme}://#{host}#{uri.path}#{uri.query ? "?#{uri.query}" : ""}"
  rescue URI::InvalidURIError => e
    Rails.logger.warn("Failed to normalize URL: #{url} - #{e.message}")
    url # Return original URL if parsing fails
  end
end
