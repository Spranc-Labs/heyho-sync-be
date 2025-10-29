# frozen_string_literal: true

module Insights
  # Calculates tab age and activity metrics from page visit data
  # Uses TabAggregate closure data when available for accurate tab lifecycle tracking
  class TabAgeCalculator
    # Calculate tab metadata for a group of visits to the same URL
    # @param visits [Array<PageVisit>] All visits to a specific URL, ordered by visited_at
    # @return [Hash] Tab metadata including age, activity, and open status
    def self.calculate(visits)
      new(visits).calculate
    end

    def initialize(visits)
      @visits = visits.sort_by(&:visited_at)
      @now = Time.current
      @tab_aggregates = load_tab_aggregates
    end

    def calculate
      return nil if @visits.empty?

      first_visit = @visits.first
      last_visit = @visits.last
      tab_lifecycle = determine_tab_lifecycle(last_visit)

      {
        # Basic visit info
        url: first_visit.url,
        title: last_visit.title, # Use most recent title
        domain: first_visit.domain,
        visit_count: @visits.size,

        # Temporal data
        opened_at: first_visit.opened_at, # Actual tab open time (from browser extension)
        first_visited_at: first_visit.visited_at,
        last_visited_at: last_visit.visited_at,
        tab_age_days: calculate_tab_age_days(first_visit, tab_lifecycle),
        days_since_last_activity: calculate_days_since_last_activity(last_visit, tab_lifecycle),

        # Tab lifecycle (from TabAggregate)
        tab_status: tab_lifecycle[:status],
        closed_at: tab_lifecycle[:closed_at],
        actual_tab_duration_seconds: tab_lifecycle[:actual_duration],

        # Activity metrics
        total_duration_seconds: @visits.sum { |v| v.duration_seconds || 0 },
        total_engagement_seconds: @visits.sum { |v| v.active_duration_seconds || 0 },
        average_engagement_rate: calculate_average_engagement_rate,

        # Behavioral indicators
        is_likely_still_open: likely_still_open?(last_visit, tab_lifecycle),
        is_single_visit: @visits.size == 1,
        is_pinned: check_pinned_status(last_visit),

        # Most recent visit for reference
        most_recent_visit: last_visit
      }
    end

    private

    # Load TabAggregate data for all visits
    def load_tab_aggregates
      visit_ids = @visits.map(&:id)
      TabAggregate.where(page_visit_id: visit_ids).index_by(&:page_visit_id)
    end

    # Determine tab lifecycle status from TabAggregate data
    # @return [Hash] { status: :open/:closed/:unknown, closed_at: Time, actual_duration: Integer }
    def determine_tab_lifecycle(last_visit)
      tab_aggregate = @tab_aggregates[last_visit.id]

      if tab_aggregate&.closed_at
        {
          status: :closed,
          closed_at: tab_aggregate.closed_at,
          actual_duration: tab_aggregate.total_time_seconds
        }
      else
        {
          status: :unknown, # No TabAggregate data - we don't know if tab is still open
          closed_at: nil,
          actual_duration: nil
        }
      end
    end

    # Calculate how many days since the tab was first opened
    # Now uses opened_at field when available for accurate tab age
    # Falls back to visited_at for backward compatibility with old data
    def calculate_tab_age_days(first_visit, tab_lifecycle)
      # Use opened_at if available (accurate tab open time from browser extension)
      # Otherwise fall back to visited_at (first activation time)
      tab_opened_at = first_visit.opened_at || first_visit.visited_at

      if tab_lifecycle[:status] == :closed && tab_lifecycle[:closed_at]
        # Tab is closed: calculate actual time tab was open
        ((tab_lifecycle[:closed_at] - tab_opened_at) / 1.day).round(1)
      else
        # Tab status unknown or open: calculate time since tab was opened
        ((@now - tab_opened_at) / 1.day).round(1)
      end
    end

    # Calculate days since last activity on this tab
    # For closed tabs, this is days since closure
    # For unknown status, this is days since last visit
    def calculate_days_since_last_activity(last_visit, tab_lifecycle)
      if tab_lifecycle[:status] == :closed && tab_lifecycle[:closed_at]
        # Tab is closed: calculate days since closure
        ((@now - tab_lifecycle[:closed_at]) / 1.day).round(1)
      else
        # Tab status unknown: calculate days since last visit
        ((@now - last_visit.visited_at) / 1.day).round(1)
      end
    end

    # Check if tab is likely still open
    # If we have TabAggregate data showing closure, tab is definitely not open
    # Otherwise use heuristic based on recent activity
    def likely_still_open?(last_visit, tab_lifecycle)
      # If we know the tab was closed, it's definitely not open
      return false if tab_lifecycle[:status] == :closed

      return false unless last_visit.duration_seconds

      # If last visit was within 24 hours and duration is long, tab is likely open
      time_since_last_visit = @now - last_visit.visited_at
      visit_recently = time_since_last_visit < 24.hours

      # Consider it open if:
      # 1. Visited recently (< 24h ago) AND has significant duration (> 5 min)
      # 2. OR the duration extends past current time (tab still recording)
      has_significant_duration = last_visit.duration_seconds > 5.minutes

      visit_recently && has_significant_duration
    end

    # Calculate average engagement rate across all visits
    def calculate_average_engagement_rate
      visits_with_engagement = @visits.select { |v| v.engagement_rate.present? }
      return 0.0 if visits_with_engagement.empty?

      visits_with_engagement.sum(&:engagement_rate) / visits_with_engagement.size
    end

    # Check if tab is pinned based on metadata
    def check_pinned_status(visit)
      return false unless visit.metadata.is_a?(Hash)

      visit.metadata['pinned'] == true || visit.metadata[:pinned] == true
    end
  end
end
