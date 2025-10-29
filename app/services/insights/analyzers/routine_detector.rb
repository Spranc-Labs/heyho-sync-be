# frozen_string_literal: true

module Insights
  module Analyzers
    # Detects routine/habitual domains based on usage patterns
    # Learns which sites are part of user's workflow vs random browsing
    class RoutineDetector
      # Routine score threshold - domains scoring above this are considered routine
      ROUTINE_THRESHOLD = 70

      # Score weights (total = 100)
      WEIGHTS = {
        visit_frequency: 40,    # How often visited
        consistency: 30,        # Spread across days
        time_pattern: 20,       # Regular time of day
        engagement_pattern: 10  # Brief/tool usage pattern
      }.freeze

      # Detect if a domain is part of user's routine
      # @param user [User] User to analyze
      # @param domain [String] Domain to check
      # @param lookback_days [Integer] Days to analyze (default: 30)
      # @return [Hash] { is_routine: Boolean, routine_type: String, score: Integer, breakdown: Hash }
      def self.detect(user:, domain:, lookback_days: 30)
        new(user:, domain:, lookback_days:).detect
      end

      def initialize(user:, domain:, lookback_days: 30)
        @user = user
        @domain = domain
        @lookback_days = lookback_days
        @visits = fetch_domain_visits
      end

      def detect
        return not_routine_result if @visits.empty?

        # Calculate individual score components
        frequency_score = calculate_frequency_score
        consistency_score = calculate_consistency_score
        time_pattern_score = calculate_time_pattern_score
        engagement_score = calculate_engagement_pattern_score

        total_score = frequency_score + consistency_score + time_pattern_score + engagement_score

        # Determine if routine and classify type
        is_routine = total_score >= ROUTINE_THRESHOLD
        routine_type = classify_routine_type if is_routine

        {
          is_routine:,
          routine_type:,
          score: total_score.round,
          breakdown: {
            visit_frequency: frequency_score.round,
            consistency: consistency_score.round,
            time_pattern: time_pattern_score.round,
            engagement_pattern: engagement_score.round
          },
          visit_count: @visits.size,
          days_active: unique_days_count
        }
      end

      private

      def fetch_domain_visits
        lookback_date = @lookback_days.days.ago

        PageVisit
          .where(user_id: @user.id)
          .where(domain: @domain)
          .where('visited_at >= ?', lookback_date)
          .order(:visited_at)
      end

      def not_routine_result
        {
          is_routine: false,
          routine_type: nil,
          score: 0,
          breakdown: {},
          visit_count: 0,
          days_active: 0
        }
      end

      # Score 1: Visit Frequency (0-40 points)
      # More visits = higher score
      def calculate_frequency_score
        visit_count = @visits.size

        case visit_count
        when 0..2
          0
        when 3..5
          10
        when 6..10
          20
        when 11..20
          30
        else # 21+
          40
        end
      end

      # Score 2: Consistency (0-30 points)
      # Spread across many days = routine, not binge usage
      def calculate_consistency_score
        unique_days = unique_days_count
        @visits.size

        return 0 if unique_days.zero?

        # Calculate spread ratio (how evenly distributed)
        unique_days.to_f

        # Penalize if all visits in one day (binge)
        if unique_days == 1
          0
        elsif unique_days >= 20 # Very spread out
          30
        elsif unique_days >= 10
          25
        elsif unique_days >= 5
          20
        elsif unique_days >= 3
          15
        else
          10
        end
      end

      # Score 3: Time Pattern (0-20 points)
      # Regular time of day = routine
      def calculate_time_pattern_score
        return 0 if @visits.empty?

        # Group by hour of day
        hour_groups = @visits.group_by { |v| v.visited_at.hour }

        # Find dominant hour (most visits)
        dominant_hour_count = hour_groups.values.map(&:size).max || 0
        total_visits = @visits.size

        # Calculate how concentrated visits are in specific hours
        concentration = dominant_hour_count.to_f / total_visits

        # High concentration = regular time pattern
        if concentration >= 0.6 # 60%+ visits at same hour
          20
        elsif concentration >= 0.4
          15
        elsif concentration >= 0.3
          10
        else
          5
        end
      end

      # Score 4: Engagement Pattern (0-10 points)
      # Brief visits = tool/utility, not content consumption
      def calculate_engagement_pattern_score
        visits_with_duration = @visits.select { |v| v.duration_seconds.present? }
        return 5 if visits_with_duration.empty? # Neutral score

        avg_duration = visits_with_duration.sum(&:duration_seconds) / visits_with_duration.size.to_f

        # Tools/utilities: Brief visits (< 5 min average)
        # Reference sites: Brief visits with high frequency
        if avg_duration < 300 && @visits.size >= 10 # < 5 min, frequent
          10
        elsif avg_duration < 600 # < 10 min
          7
        else
          3 # Longer visits = content consumption
        end
      end

      # Classify the type of routine
      def classify_routine_type
        avg_duration = calculate_average_duration
        visit_count = @visits.size
        unique_days = unique_days_count

        # Work tool: Frequent, brief, spread across many days
        return 'work_tool' if visit_count >= 15 && avg_duration < 600 && unique_days >= 10

        # Reference site: Very frequent, very brief
        return 'reference' if visit_count >= 20 && avg_duration < 300

        # Entertainment routine: Moderate frequency, specific time pattern
        return 'entertainment_routine' if visit_count >= 8 && visit_count < 20

        # Default
        'routine_site'
      end

      def calculate_average_duration
        visits_with_duration = @visits.select { |v| v.duration_seconds.present? }
        return 0 if visits_with_duration.empty?

        visits_with_duration.sum(&:duration_seconds) / visits_with_duration.size.to_f
      end

      def unique_days_count
        @visits.map { |v| v.visited_at.to_date }.uniq.size
      end
    end
  end
end
