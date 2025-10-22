# frozen_string_literal: true

# Service to detect "hoarder tabs" - tabs open for extended periods with minimal engagement
# Criteria:
# - Tab open time > 30 minutes (default)
# - Engagement rate < 20% (default)
# - Not already in reading list
class HoarderDetectionService
  DEFAULT_MIN_OPEN_TIME = 30.minutes
  DEFAULT_MAX_ENGAGEMENT = 0.2

  def self.call(user, min_open_time: DEFAULT_MIN_OPEN_TIME, max_engagement: DEFAULT_MAX_ENGAGEMENT)
    new(user, min_open_time, max_engagement).call
  end

  def initialize(user, min_open_time, max_engagement)
    @user = user
    @min_open_time = min_open_time
    @max_engagement = max_engagement
  end

  def call
    detect_hoarder_tabs
  end

  private

  def detect_hoarder_tabs
    # Find page visits that match hoarder criteria
    candidate_visits = PageVisit
      .where(user_id: @user.id)
      .where('duration_seconds >= ?', @min_open_time.to_i)
      .where('engagement_rate <= ?', @max_engagement)
      .where.not(id: already_saved_visit_ids)
      .order(visited_at: :desc)

    # Group by URL to avoid duplicates
    unique_visits = candidate_visits.group_by(&:url).transform_values(&:first)

    # Convert to hoarder tab objects
    unique_visits.values.map do |visit|
      build_hoarder_tab(visit)
    end
  end

  def already_saved_visit_ids
    # Get page_visit_ids that are already in the reading list
    ReadingListItem
      .where(user_id: @user.id)
      .where.not(page_visit_id: nil)
      .pluck(:page_visit_id)
  end

  def build_hoarder_tab(visit)
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
