# frozen_string_literal: true

module Detections
  # Service to detect research sessions - browsing bursts where multiple tabs were opened
  # Criteria:
  # - Multiple tabs (>= 3) opened within a time window (default: 15 minutes)
  # - Session duration > minimum threshold (default: 10 minutes)
  # - Not already saved as a research session
  class ResearchSessionDetectionService
  DEFAULT_MIN_TABS = 3
  DEFAULT_TIME_WINDOW = 15.minutes
  DEFAULT_MIN_DURATION = 10.minutes

  def self.call(user, min_tabs: DEFAULT_MIN_TABS, time_window: DEFAULT_TIME_WINDOW, min_duration: DEFAULT_MIN_DURATION)
    new(user, min_tabs, time_window, min_duration).call
  end

  def initialize(user, min_tabs, time_window, min_duration)
    @user = user
    @min_tabs = min_tabs
    @time_window = time_window
    @min_duration = min_duration
  end

  def call
    detect_research_sessions
  end

  private

  def detect_research_sessions
    # Get all page visits ordered by visit time
    visits = PageVisit
      .where(user_id: @user.id)
      .where.not(id: already_in_sessions)
      .order(visited_at: :asc)

    # Group visits into potential sessions based on time proximity
    sessions = group_visits_into_sessions(visits)

    # Filter sessions that meet criteria and build session objects
    sessions
      .select { |session| valid_session?(session) }
      .map { |session| build_research_session(session) }
  end

  def group_visits_into_sessions(visits)
    sessions = []
    current_session = []
    session_start = nil

    visits.each do |visit|
      if current_session.empty?
        # Start new session
        current_session = [visit]
        session_start = visit.visited_at
      elsif visit.visited_at - session_start <= @time_window
        # Add to current session
        current_session << visit
      else
        # Save current session and start new one
        sessions << current_session if current_session.size >= @min_tabs
        current_session = [visit]
        session_start = visit.visited_at
      end
    end

    # Don't forget the last session
    sessions << current_session if current_session.size >= @min_tabs

    sessions
  end

  def valid_session?(visits)
    return false if visits.size < @min_tabs

    session_start = visits.first.visited_at
    session_end = visits.max_by(&:visited_at).visited_at

    duration = session_end - session_start
    duration >= @min_duration.to_i
  end

  def build_research_session(visits)
    session_start = visits.first.visited_at
    session_end = visits.max_by(&:visited_at).visited_at

    # Extract domains and determine primary domain
    domains = visits.filter_map(&:domain).uniq
    primary_domain = visits.group_by(&:domain).max_by { |_k, v| v.size }&.first

    # Calculate aggregated metrics
    total_duration = visits.sum(&:duration_seconds)
    avg_engagement = visits.filter_map(&:engagement_rate).sum / visits.size.to_f

    {
      session_name: generate_session_name(primary_domain, session_start),
      session_start:,
      session_end:,
      tab_count: visits.size,
      primary_domain:,
      domains:,
      total_duration_seconds: total_duration,
      avg_engagement_rate: avg_engagement,
      page_visit_ids: visits.map(&:id),
      status: 'detected'
    }
  end

  def generate_session_name(domain, start_time)
    domain_name = domain&.split('.')&.first&.capitalize || 'Research'
    timestamp = start_time.strftime('%b %d, %I:%M%p')
    "#{domain_name} - #{timestamp}"
  end

  def already_in_sessions
    # Get page_visit_ids that are already part of a research session
    ResearchSessionTab
      .joins(:research_session)
      .where(research_sessions: { user_id: @user.id })
      .pluck(:page_visit_id)
  end
  end
end
