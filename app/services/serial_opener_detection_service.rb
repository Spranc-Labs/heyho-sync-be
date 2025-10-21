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
    # Find page visits that match serial opener criteria
    candidate_visits = PageVisit
      .where(user_id: @user.id)
      .where('visit_count >= ?', @min_visits)
      .where('duration_seconds < ?', @max_total_engagement.to_i)
      .where.not(id: already_saved_visit_ids)
      .order(visit_count: :desc, last_visit_at: :desc)

    # Group by URL to get unique resources
    unique_visits = candidate_visits.group_by(&:url).transform_values(&:first)

    # Convert to serial opener objects
    unique_visits.values.map do |visit|
      build_serial_opener(visit)
    end
  end

  def already_saved_visit_ids
    # Get page_visit_ids that are already in the reading list
    ReadingListItem
      .where(user_id: @user.id)
      .where.not(page_visit_id: nil)
      .pluck(:page_visit_id)
  end

  def build_serial_opener(visit)
    {
      page_visit_id: visit.id,
      url: visit.url,
      title: visit.title,
      domain: visit.domain,
      visit_count: visit.visit_count,
      total_engagement_seconds: visit.duration_seconds,
      avg_engagement_per_visit: visit.duration_seconds.to_f / visit.visit_count,
      first_visit_at: visit.first_visit_at,
      last_visit_at: visit.last_visit_at,
      engagement_rate: visit.engagement_rate,
      suggested_action: 'save_to_reading_list'
    }
  end
end
