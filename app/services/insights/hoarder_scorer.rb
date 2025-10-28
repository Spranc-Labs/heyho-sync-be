# frozen_string_literal: true

module Insights
  # Multi-factor scoring system for hoarder tab detection
  # Uses tab age as primary signal with context-aware adjustments
  class HoarderScorer
    # Score thresholds
    HOARDER_THRESHOLD = 60 # Score >= 60 is considered a hoarder tab
    HIGH_CONFIDENCE_THRESHOLD = 80 # Score >= 80 is high confidence hoarder

    # Scoring weights (designed to total ~100 for a clear hoarder)
    WEIGHTS = {
      tab_age_7_days: 40,           # Tab open for 7+ days
      tab_age_3_days: 25,           # Tab open for 3-7 days
      tab_age_1_day: 10,            # Tab open for 1-3 days
      inactive_2_days: 30,          # No activity for 2+ days
      inactive_1_day: 15,           # No activity for 1-2 days
      single_visit: 20,             # Opened once and forgotten
      content_site: 15,             # Content meant to be consumed
      low_engagement: 10,           # Engagement rate < 10%
      lenient_penalty: -50,         # Significant reduction for productivity tools
      strict_bonus: 15              # Bonus for clear hoarder patterns
    }.freeze

    # Calculate hoarder score for a tab
    # @param tab_metadata [Hash] Tab metadata from TabAgeCalculator
    # @param domain_context [Hash] Domain context from DomainContextAnalyzer
    # @return [Hash] Score breakdown and determination
    def self.calculate(tab_metadata:, domain_context:)
      new(tab_metadata:, domain_context:).calculate
    end

    def initialize(tab_metadata:, domain_context:)
      @tab_metadata = tab_metadata
      @domain_context = domain_context
      @score_breakdown = {}
    end

    def calculate
      # Early exit for excluded tabs
      return exclusion_result if should_exclude?

      # Calculate individual score components
      score = 0
      score += calculate_tab_age_score
      score += calculate_inactivity_score
      score += calculate_visit_pattern_score
      score += calculate_engagement_score
      score += calculate_domain_context_score

      # Ensure score doesn't go negative
      score = [score, 0].max

      result = {
        total_score: score,
        is_hoarder: score >= HOARDER_THRESHOLD,
        confidence_level: confidence_level(score),
        score_breakdown: @score_breakdown,
        reason: generate_reason(score)
      }

      # Add flag if this overrode a conditional whitelist
      if @domain_context[:is_whitelisted] && @domain_context[:is_conditional_whitelist] && severe_hoarder_pattern?
        result[:whitelist_override] = {
          overridden: true,
          whitelist_type: @domain_context[:whitelist_reason],
          override_reason: 'Severe hoarder pattern (7+ days, single visit, low engagement)'
        }
      end

      result
    end

    private

    # Exclusions: Never flag these as hoarders
    def should_exclude?
      # Never flag pinned tabs
      return true if @tab_metadata[:is_pinned]

      # Check whitelist with conditional logic
      if @domain_context[:is_whitelisted]
        # Strong whitelist (Gmail, work tools) - always exclude
        return true unless @domain_context[:is_conditional_whitelist]

        # Conditional whitelist (YouTube, Reddit) - check if severe hoarder
        # Only exclude if NOT a severe hoarder pattern
        return true unless severe_hoarder_pattern?
      end

      # Never flag tabs with lenient rules (productivity tools with recent activity)
      return true if @domain_context[:should_apply_lenient_rules]

      false
    end

    # Check if tab matches severe hoarder pattern (overrides conditional whitelist)
    # Severe pattern: 7+ days old, single visit, low engagement
    def severe_hoarder_pattern?
      @tab_metadata[:tab_age_days] >= 7.0 &&
        @tab_metadata[:is_single_visit] &&
        @tab_metadata[:average_engagement_rate] < 0.1
    end

    def exclusion_result
      reason = if @tab_metadata[:is_pinned]
                 'Excluded: Pinned tab'
               elsif @domain_context[:is_whitelisted] && !@domain_context[:is_conditional_whitelist]
                 "Excluded: Strong whitelist (#{@domain_context[:whitelist_reason]})"
               elsif @domain_context[:is_whitelisted] && @domain_context[:is_conditional_whitelist] && !severe_hoarder_pattern?
                 "Excluded: Conditional whitelist (#{@domain_context[:whitelist_reason]}, not severe pattern)"
               else
                 'Excluded: Productivity tool with recent activity'
               end

      {
        total_score: 0,
        is_hoarder: false,
        confidence_level: :excluded,
        score_breakdown: {},
        reason:
      }
    end

    # Factor 1: Tab age (PRIMARY SIGNAL)
    def calculate_tab_age_score
      age_days = @tab_metadata[:tab_age_days]
      score = 0

      if age_days >= 7.0
        score = WEIGHTS[:tab_age_7_days]
        @score_breakdown[:tab_age] = { points: score, reason: "Tab open for #{age_days.round(1)} days (7+ days)" }
      elsif age_days >= 3.0
        score = WEIGHTS[:tab_age_3_days]
        @score_breakdown[:tab_age] = { points: score, reason: "Tab open for #{age_days.round(1)} days (3-7 days)" }
      elsif age_days >= 1.0
        score = WEIGHTS[:tab_age_1_day]
        @score_breakdown[:tab_age] = { points: score, reason: "Tab open for #{age_days.round(1)} days (1-3 days)" }
      else
        @score_breakdown[:tab_age] = { points: 0, reason: 'Tab recently opened (< 1 day)' }
      end

      score
    end

    # Factor 2: Inactivity
    def calculate_inactivity_score
      inactive_days = @tab_metadata[:days_since_last_activity]
      score = 0

      if inactive_days >= 2.0
        score = WEIGHTS[:inactive_2_days]
        @score_breakdown[:inactivity] =
          { points: score, reason: "No activity for #{inactive_days.round(1)} days (2+ days)" }
      elsif inactive_days >= 1.0
        score = WEIGHTS[:inactive_1_day]
        @score_breakdown[:inactivity] =
          { points: score, reason: "No activity for #{inactive_days.round(1)} days (1-2 days)" }
      else
        @score_breakdown[:inactivity] = { points: 0, reason: 'Recent activity (< 1 day)' }
      end

      score
    end

    # Factor 3: Visit pattern
    def calculate_visit_pattern_score
      score = 0

      if @tab_metadata[:is_single_visit] && @tab_metadata[:tab_age_days] >= 1.0
        score = WEIGHTS[:single_visit]
        @score_breakdown[:visit_pattern] = { points: score, reason: 'Opened once and forgotten' }
      elsif @tab_metadata[:visit_count] >= 5
        # Frequent revisits suggest it's not a hoarder
        @score_breakdown[:visit_pattern] = { points: 0, reason: 'Frequently revisited (5+ visits)' }
      else
        @score_breakdown[:visit_pattern] = { points: 0, reason: "#{@tab_metadata[:visit_count]} visits" }
      end

      score
    end

    # Factor 4: Engagement
    def calculate_engagement_score
      engagement_rate = @tab_metadata[:average_engagement_rate]
      score = 0

      if engagement_rate < 0.1 && !@tab_metadata[:is_likely_still_open]
        score = WEIGHTS[:low_engagement]
        @score_breakdown[:engagement] =
          { points: score, reason: "Low engagement (#{(engagement_rate * 100).round(1)}%)" }
      else
        @score_breakdown[:engagement] = { points: 0, reason: "Engagement: #{(engagement_rate * 100).round(1)}%" }
      end

      score
    end

    # Factor 5: Domain context (adjustments based on domain type)
    def calculate_domain_context_score
      score = 0

      # Apply strict rules for content sites and obvious hoarders
      if @domain_context[:should_apply_strict_rules]
        score += WEIGHTS[:strict_bonus]
        @score_breakdown[:domain_context] = {
          points: WEIGHTS[:strict_bonus],
          reason: "Content/doc site with hoarder pattern (#{@domain_context[:domain_type]})"
        }
      # Apply content site bonus for single visits
      elsif @domain_context[:domain_type] == :content_site
        score += WEIGHTS[:content_site]
        @score_breakdown[:domain_context] = {
          points: WEIGHTS[:content_site],
          reason: 'Content site (articles/blogs typically read later)'
        }
      else
        @score_breakdown[:domain_context] = {
          points: 0,
          reason: "Domain type: #{@domain_context[:domain_type]}"
        }
      end

      score
    end

    def confidence_level(score)
      return :excluded if score.zero? && should_exclude?
      return :high if score >= HIGH_CONFIDENCE_THRESHOLD
      return :medium if score >= HOARDER_THRESHOLD
      return :low if score >= 40

      :not_hoarder
    end

    def generate_reason(score)
      return 'Not a hoarder tab' if score < HOARDER_THRESHOLD

      reasons = []

      # Primary reasons based on highest scoring factors
      top_factors = @score_breakdown.sort_by { |_k, v| -v[:points] }.first(3)
      top_factors.each do |_factor, data|
        reasons << data[:reason] if (data[:points]).positive?
      end

      reasons.join(' • ')
    end
  end
end
