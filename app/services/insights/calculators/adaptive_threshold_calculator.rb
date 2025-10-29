# frozen_string_literal: true

module Insights
  module Calculators
  # Calculates adaptive thresholds for behavior classification based on time period
  # Thresholds scale with the time window to maintain consistent classification
  #
  # Scientific basis:
  # - Compulsive checking threshold (50 visits/week) aligns with DSM-5 OCD criteria
  #   (>1 hour/day on compulsions = 7+ hours/week = ~7 checks/day)
  # - Tab hoarding research (CMU) shows 30% of users self-identify as "tab hoarders"
  # - Engagement time benchmarks: 52-54s average page visit, <15s for quick checks
  class AdaptiveThresholdCalculator
    # Base thresholds for a 7-day (week) period
    BASE_PERIOD_DAYS = 7.0

    # Minimum period for meaningful analysis (12 hours = 0.5 days)
    # Below this threshold, behavioral patterns may not be statistically significant
    MIN_PERIOD_DAYS = 0.5

    # Serial opener detection thresholds
    # Based on CMU tab hoarding research: frequent opening with minimal engagement
    SERIAL_OPENER_MIN_VISITS_PER_DAY = 0.43 # ~3 visits per week baseline
    SERIAL_OPENER_BASE_MIN_VISITS = 3 # Minimum visits per week
    SERIAL_OPENER_ABSOLUTE_MIN_VISITS = 2 # Floor for very short periods
    SERIAL_OPENER_MAX_ENGAGEMENT_MINUTES = 2 # Maximum total engagement per week

    # Behavior classification thresholds (visits per week)
    # Aligned with DSM-5 clinical criteria for compulsive behaviors
    COMPULSIVE_CHECKING_VISITS_PER_WEEK = 50 # ~7 per day (clinical threshold)
    FREQUENT_MONITORING_VISITS_PER_WEEK = 20 # ~3 per day (sub-clinical)
    REGULAR_REFERENCE_VISITS_PER_WEEK = 10 # ~1-2 per day (normal reference)

    # Engagement thresholds (seconds per visit)
    # Based on web engagement research: average time on page is 52-54 seconds
    QUICK_GLANCE_SECONDS = 5 # Instantaneous check
    BRIEF_CHECK_SECONDS = 15 # Quick scan
    SCAN_SECONDS = 60 # Full page read
    # Anything above SCAN_SECONDS is classified as :shallow_work

    # Time pattern thresholds (hours between visits)
    COMPULSIVE_HOURS_BETWEEN = 0.5 # 30 minutes (very frequent)
    FREQUENT_HOURS_BETWEEN = 2.0 # Every 2 hours
    REGULAR_HOURS_BETWEEN = 8.0 # Working day frequency

    def initialize(days_in_period:)
      @days_in_period = days_in_period.to_f
      validate_period!
      @scale_factor = @days_in_period / BASE_PERIOD_DAYS
    end

    attr_reader :days_in_period

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
      return :periodic_revisit if avg_hours_between.nil?

      raise ArgumentError, 'avg_hours_between must be non-negative' if avg_hours_between.negative?

      # Zero or near-zero hours = instant/immediate reopening = compulsive pattern
      return :compulsive_checking if avg_hours_between < COMPULSIVE_HOURS_BETWEEN

      if avg_hours_between < FREQUENT_HOURS_BETWEEN
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
      return :quick_glance if avg_seconds_per_visit.nil?

      raise ArgumentError, 'avg_seconds_per_visit must be non-negative' if avg_seconds_per_visit.negative?

      # Zero seconds (instantaneous visit) = quick glance
      return :quick_glance if avg_seconds_per_visit < QUICK_GLANCE_SECONDS

      if avg_seconds_per_visit < BRIEF_CHECK_SECONDS
        :brief_check
      elsif avg_seconds_per_visit < SCAN_SECONDS
        :scan
      else
        :shallow_work
      end
    end

    # Get the minimum number of visits to be considered a serial opener
    # Uses visits-per-day approach to maintain consistency across time periods
    # @return [Integer] Minimum visit count for this period
    def min_serial_opener_visits
      # Calculate based on visits per day to keep consistent across periods
      min_visits = (SERIAL_OPENER_MIN_VISITS_PER_DAY * @days_in_period).round
      # Ensure at least absolute minimum even for very short periods
      [min_visits, SERIAL_OPENER_ABSOLUTE_MIN_VISITS].max
    end

    # Get the maximum total engagement time to be considered a serial opener
    # Scales with period length (2 minutes per week baseline)
    # @return [Integer] Maximum engagement in seconds
    def max_serial_opener_engagement_seconds
      # Base: 2 minutes per week (reduced from 5 based on research)
      base_seconds = SERIAL_OPENER_MAX_ENGAGEMENT_MINUTES.minutes
      scale_threshold(base_seconds).to_i
    end

    # Check if a resource qualifies as a serial opener based on visits per day
    # Uses consistent visits-per-day metric regardless of analysis period
    # @param visit_count [Integer] Total number of visits
    # @param days [Float] Number of days in the period (optional, uses instance default)
    # @return [Boolean] True if qualifies as serial opener
    def qualifies_as_serial_opener?(visit_count, days = nil)
      period_days = days || @days_in_period
      return false if period_days.nil? || period_days.zero?

      raise ArgumentError, 'visit_count must be non-negative' if visit_count.negative?
      raise ArgumentError, 'days must be positive' if days && days <= 0

      visits_per_day = visit_count.to_f / period_days
      visits_per_day >= SERIAL_OPENER_MIN_VISITS_PER_DAY
    end

    # Get the minimum visits per day threshold for serial opener detection
    # This threshold is consistent across all time periods
    # @return [Float] Minimum visits per day (0.43 = ~3 visits per week)
    def min_visits_per_day_threshold
      SERIAL_OPENER_MIN_VISITS_PER_DAY
    end

    private

    attr_reader :scale_factor

    # Validate that the period is within acceptable bounds
    # @raise [ArgumentError] if period is too short for meaningful analysis
    def validate_period!
      if @days_in_period <= 0
        raise ArgumentError, 'days_in_period must be positive'
      elsif @days_in_period < MIN_PERIOD_DAYS
        raise ArgumentError,
              "days_in_period must be at least #{MIN_PERIOD_DAYS} days for meaningful analysis " \
              "(got #{@days_in_period})"
      end
    end

    # Scale a threshold value based on the period length
    # @param base_value [Numeric] Base value for 7-day period
    # @return [Integer] Scaled value rounded to nearest integer
    def scale_threshold(base_value)
      (base_value * scale_factor).round
    end
  end
  end
end
