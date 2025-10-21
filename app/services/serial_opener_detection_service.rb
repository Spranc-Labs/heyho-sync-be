# frozen_string_literal: true

# Service to detect "serial openers" - resources repeatedly opened but never finished
# Criteria:
# - Visit count >= 3 (default)
# - Total engagement time < 5 minutes (default)
# - Not already in reading list
class SerialOpenerDetectionService
  DEFAULT_MIN_VISITS = 3
  DEFAULT_MAX_TOTAL_ENGAGEMENT = 5.minutes

  def self.call(user, min_visits: DEFAULT_MIN_VISITS, max_total_engagement: DEFAULT_MAX_TOTAL_ENGAGEMENT)
    new(user, min_visits, max_total_engagement).call
  end

  def initialize(user, min_visits, max_total_engagement)
    @user = user
    @min_visits = min_visits
    @max_total_engagement = max_total_engagement
  end

  def call
    detect_serial_openers
  end

  private

  def detect_serial_openers
    # Group page visits by URL to find repeatedly visited resources
    all_visits = PageVisit
      .where(user_id: @user.id)
      .where.not(id: already_saved_visit_ids)
      .select(:id, :url, :title, :domain, :duration_seconds, :engagement_rate, :visited_at)

    # Group by URL and filter for URLs with multiple visits
    grouped_visits = all_visits.group_by(&:url)

    serial_openers = grouped_visits.filter_map do |url, visits|
      next if visits.size < @min_visits

      total_duration = visits.sum(&:duration_seconds)
      next if total_duration >= @max_total_engagement.to_i

      build_serial_opener(url, visits)
    end

    serial_openers.sort_by { |so| -so[:visit_count] }
  end

  def already_saved_visit_ids
    # Get page_visit_ids that are already in the reading list
    ReadingListItem
      .where(user_id: @user.id)
      .where.not(page_visit_id: nil)
      .pluck(:page_visit_id)
  end

  def build_serial_opener(url, visits)
    most_recent = visits.max_by(&:visited_at)
    total_duration = visits.sum(&:duration_seconds)
    avg_engagement = visits.filter_map(&:engagement_rate).sum / visits.size.to_f

    {
      page_visit_id: most_recent.id,
      url:,
      title: most_recent.title,
      domain: most_recent.domain,
      visit_count: visits.size,
      total_engagement_seconds: total_duration,
      avg_engagement_per_visit: total_duration.to_f / visits.size,
      first_visit_at: visits.min_by(&:visited_at).visited_at,
      last_visit_at: most_recent.visited_at,
      engagement_rate: avg_engagement,
      suggested_action: 'save_to_reading_list'
    }
  end
end
