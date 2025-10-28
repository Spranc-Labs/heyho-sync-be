# frozen_string_literal: true

module Insights
  # Calculates adaptive thresholds for behavior classification based on time period
  # Thresholds scale with the time window to maintain consistent classification
  class AdaptiveThresholdCalculator
    # Base thresholds for a 7-day (week) period
    BASE_PERIOD_DAYS = 7.0

    # Serial opener detection threshold (visits per day)
    # 0.43 visits/day = ~3 visits per week
    SERIAL_OPENER_MIN_VISITS_PER_DAY = 0.43

    # Behavior classification thresholds (visits per week)
    COMPULSIVE_CHECKING_VISITS_PER_WEEK = 50
    FREQUENT_MONITORING_VISITS_PER_WEEK = 20
    REGULAR_REFERENCE_VISITS_PER_WEEK = 10

    # Engagement thresholds (seconds per visit)
    QUICK_GLANCE_SECONDS = 5
    BRIEF_CHECK_SECONDS = 15
    SCAN_SECONDS = 60

    # Time pattern thresholds (hours between visits)
    COMPULSIVE_HOURS_BETWEEN = 0.5 # 30 minutes
    FREQUENT_HOURS_BETWEEN = 2.0
    REGULAR_HOURS_BETWEEN = 8.0

    def initialize(days_in_period:)
      @days_in_period = days_in_period.to_f
      @scale_factor = @days_in_period / BASE_PERIOD_DAYS
    end

    # Get minimum visit count threshold for behavior classification
    # @param behavior_type [Symbol] :compulsive, :frequent, or :regular
    # @return [Integer] Minimum visit count for this period
    def min_visits_for_behavior(behavior_type)
      base_visits = case behavior_type
                    when :compulsive
                      COMPULSIVE_CHECKING_VISITS_PER_WEEK
                    when :frequent
                      FREQUENT_MONITORING_VISITS_PER_WEEK
                    when :regular
                      REGULAR_REFERENCE_VISITS_PER_WEEK
                    else
                      raise ArgumentError, "Unknown behavior type: #{behavior_type}"
                    end

      scale_threshold(base_visits)
    end

    # Classify behavior based on visit count
    # @param visit_count [Integer] Total visits in the period
    # @return [Symbol] :compulsive_checking, :frequent_monitoring, :regular_reference, or :periodic_revisit
    def classify_behavior_by_visits(visit_count)
      if visit_count >= min_visits_for_behavior(:compulsive)
        :compulsive_checking
      elsif visit_count >= min_visits_for_behavior(:frequent)
        :frequent_monitoring
      elsif visit_count >= min_visits_for_behavior(:regular)
        :regular_reference
      else
        :periodic_revisit
      end
    end

    # Classify behavior based on average hours between visits
    # @param avg_hours_between [Float] Average hours between consecutive visits
    # @return [Symbol] :compulsive_checking, :frequent_monitoring, :regular_reference, or :periodic_revisit
    def classify_behavior_by_frequency(avg_hours_between)
      return :periodic_revisit if avg_hours_between.nil? || avg_hours_between.zero?

      if avg_hours_between < COMPULSIVE_HOURS_BETWEEN
        :compulsive_checking
      elsif avg_hours_between < FREQUENT_HOURS_BETWEEN
        :frequent_monitoring
      elsif avg_hours_between < REGULAR_HOURS_BETWEEN
        :regular_reference
      else
        :periodic_revisit
      end
    end

    # Classify engagement pattern based on average seconds per visit
    # @param avg_seconds_per_visit [Float] Average duration per visit
    # @return [Symbol] :quick_glance, :brief_check, :scan, or :shallow_work
    def classify_engagement_type(avg_seconds_per_visit)
      return :quick_glance if avg_seconds_per_visit.nil? || avg_seconds_per_visit.zero?

      if avg_seconds_per_visit < QUICK_GLANCE_SECONDS
        :quick_glance
      elsif avg_seconds_per_visit < BRIEF_CHECK_SECONDS
        :brief_check
      elsif avg_seconds_per_visit < SCAN_SECONDS
        :scan
      else
        :shallow_work
      end
    end

    # Get the minimum number of visits to be considered a serial opener
    # Scales with period length
    # @return [Integer] Minimum visit count
    def min_serial_opener_visits
      # Base minimum is 3 visits per week
      base_min = 3
      scaled = scale_threshold(base_min)
      # Ensure at least 2 visits even for very short periods
      [scaled, 2].max
    end

    # Get the maximum total engagement time to be considered a serial opener
    # Scales with period length
    # @return [Integer] Maximum engagement in seconds
    def max_serial_opener_engagement_seconds
      # Base: 5 minutes per week
      base_seconds = 5.minutes
      scale_threshold(base_seconds).to_i
    end

    # Get the minimum visits per day threshold for serial opener detection
    # This threshold is consistent across all time periods
    # @return [Float] Minimum visits per day (0.43 = ~3 visits per week)
    def min_visits_per_day_threshold
      SERIAL_OPENER_MIN_VISITS_PER_DAY
    end

    # Check if a resource qualifies as a serial opener based on visits per day
    # @param visit_count [Integer] Total number of visits
    # @param days [Float] Number of days in the period
    # @return [Boolean] True if qualifies as serial opener
    def qualifies_as_serial_opener?(visit_count, days = nil)
      period_days = days || @days_in_period
      return false if period_days.nil? || period_days.zero?

      visits_per_day = visit_count.to_f / period_days
      visits_per_day >= SERIAL_OPENER_MIN_VISITS_PER_DAY
    end

    # Public accessor for days_in_period (needed by insight generator)
    # @return [Float] Number of days in the analysis period
    attr_reader :days_in_period

    private

    attr_reader :scale_factor

    # Scale a threshold value based on the period length
    # @param base_value [Numeric] Base value for 7-day period
    # @return [Integer] Scaled value rounded to nearest integer
    def scale_threshold(base_value)
      (base_value * scale_factor).round
    end
  end
end
