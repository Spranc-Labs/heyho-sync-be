# frozen_string_literal: true

module Insights
  module SerialOpeners
    # Generates rule-based behavioral insights for serial openers
    # Uses templates and pattern matching - no ML/LLM required
    class SerialOpenerInsightGenerator
    # Domain pattern keywords for purpose inference
    DOMAIN_PATTERNS = {
      'notion.so' => { purpose: :documentation, keywords: { 'issue|tracker|ticket' => :task_tracking,
                                                            'meeting|notes' => :note_taking, 'doc|documentation' => :reference } },
      'notion.site' => { purpose: :documentation, keywords: {} },
      'github.com' => { purpose: :code_development, keywords: { 'pull|pr' => :code_review, 'issues' => :issue_tracking,
                                                                'repositories|repos' => :repo_browsing } },
      'mail.google.com' => { purpose: :email, keywords: {} },
      'gmail.com' => { purpose: :email, keywords: {} },
      'x.com' => { purpose: :social_media, keywords: {} },
      'twitter.com' => { purpose: :social_media, keywords: {} },
      'linkedin.com' => { purpose: :social_media, keywords: {} },
      'facebook.com' => { purpose: :social_media, keywords: {} },
      'youtube.com' => { purpose: :video_content, keywords: {} },
      'slack.com' => { purpose: :communication, keywords: {} },
      'discord.com' => { purpose: :communication, keywords: {} }
    }.freeze

    # Insight templates for different behavior × purpose combinations
    INSIGHT_TEMPLATES = {
      compulsive_checking: {
        task_tracking: "You're checking this task tracker %<visits_per_day>s times per day, spending only " \
                       '%<avg_seconds>ss each time. This suggests anxious waiting for updates rather than active work.',
        email: 'You check your email %<visits_per_day>s times per day with %<avg_seconds>ss per visit. ' \
               'This constant inbox checking is disrupting your focus.',
        social_media: 'Checking %<domain>s %<visits_per_day>s times per day indicates compulsive behavior. ' \
                      'This is fragmenting your attention.',
        code_review: "You've checked this PR %<visit_count>s times (%<visits_per_day>s/day). " \
                     "You're likely anxiously waiting for reviews or CI results.",
        communication: 'You check %<domain>s %<visits_per_day>s times per day. Enable notifications ' \
                       'instead of constant manual checking.',
        default: 'You check this %<visits_per_day>s times per day, spending only %<avg_seconds>ss each time. ' \
                 'This frequent checking pattern is inefficient.'
      },
      frequent_monitoring: {
        task_tracking: 'You check this task tracker %<visits_per_day>s times per day for quick status updates.',
        code_review: 'You monitor this PR frequently (%<visits_per_day>s/day) for updates.',
        default: 'You check this %<visits_per_day>s times per day for monitoring purposes.'
      },
      regular_reference: {
        documentation: 'You reference this %<visits_per_day>s times per day. Consider pinning or bookmarking.',
        default: 'You come back to this regularly (%<visits_per_day>s times per day).'
      },
      periodic_revisit: {
        default: 'You revisit this occasionally (%<visit_count>s times total).'
      }
    }.freeze

    # Actionable suggestions for different inferred purposes
    SUGGESTION_TEMPLATES = {
      task_tracking: 'Enable Notion notifications or Slack integration for task updates. ' \
                     'Stop manually checking every %<avg_hours_between>s hours.',
      email: 'Turn on desktop notifications. Schedule specific email check times (e.g., 9am, 1pm, 4pm) ' \
             'instead of checking %<visits_per_day>s times per day.',
      social_media: 'Set specific times to check social media (e.g., lunch, end of day). ' \
                    'Consider app blockers during focus work hours.',
      code_review: 'Enable GitHub email/Slack notifications for PR reviews, comments, and CI status. ' \
                   'You will know immediately when action is needed.',
      communication: 'Enable desktop notifications for %<domain>s. Stop the constant manual checking.',
      documentation: 'Pin this tab or add to bookmarks bar for quick access. %<visit_count>s reopenings is inefficient.',
      video_content: 'If you keep coming back, add to a Watch Later playlist instead of reopening %<visit_count>s times.',
      default: 'Consider bookmarking this instead of reopening it %<visit_count>s times.'
    }.freeze

    def initialize(calculator:)
      @calculator = calculator
    end

    # Generate enriched insights for a serial opener
    # @param opener_data [Hash] Raw serial opener data from detection service
    # @param visits [Array<PageVisit>] Individual visits for time pattern analysis
    # @return [Hash] Enriched data with insights
    def generate_insights(opener_data, visits = [])
      # Calculate frequency metrics
      time_span_hours = calculate_time_span_hours(opener_data)
      avg_hours_between = calculate_avg_hours_between(time_span_hours, opener_data[:visit_count])
      visits_per_day = calculate_visits_per_day(opener_data[:visit_count], @calculator.days_in_period)

      # Classify patterns
      behavior_type = @calculator.classify_behavior_by_frequency(avg_hours_between)
      engagement_type = @calculator.classify_engagement_type(opener_data[:avg_engagement_per_visit])
      inferred_purpose = infer_purpose(opener_data[:domain], opener_data[:title], opener_data[:category])

      # Calculate time patterns if visits provided
      time_patterns = visits.any? ? calculate_time_patterns(visits) : {}

      # Calculate efficiency score
      efficiency_score = calculate_efficiency_score(
        opener_data[:total_engagement_seconds],
        opener_data[:visit_count]
      )

      # Generate insight text
      behavioral_insight = generate_insight_text(
        behavior_type:,
        inferred_purpose:,
        visits_per_day:,
        avg_seconds: opener_data[:avg_engagement_per_visit].round(1),
        visit_count: opener_data[:visit_count],
        domain: opener_data[:domain]
      )

      actionable_suggestion = generate_suggestion_text(
        inferred_purpose:,
        visits_per_day:,
        visit_count: opener_data[:visit_count],
        avg_hours_between:,
        domain: opener_data[:domain]
      )

      # Merge all data
      opener_data.merge(
        time_span_hours: time_span_hours.round(1),
        avg_hours_between_visits: avg_hours_between&.round(2),
        visits_per_day: visits_per_day.round(1),
        behavior_type: behavior_type.to_s,
        engagement_type: engagement_type.to_s,
        inferred_purpose: inferred_purpose.to_s,
        efficiency_score: efficiency_score.round(1),
        behavioral_insight:,
        actionable_suggestion:,
        **time_patterns
      )
    end

    private

    attr_reader :calculator

    def calculate_time_span_hours(opener_data)
      return 0.0 if opener_data[:first_visit_at] == opener_data[:last_visit_at]

      ((opener_data[:last_visit_at] - opener_data[:first_visit_at]) / 1.hour).to_f
    end

    def calculate_avg_hours_between(time_span_hours, visit_count)
      return nil if visit_count <= 1 || time_span_hours.zero?

      time_span_hours / (visit_count - 1).to_f
    end

    def calculate_visits_per_day(visit_count, days_in_period)
      return 0.0 if days_in_period.nil? || days_in_period.zero?

      visit_count.to_f / days_in_period
    end

    def calculate_efficiency_score(total_engagement_seconds, visit_count)
      # Assume 5 seconds overhead per tab open/close
      overhead_seconds = visit_count * 5.0
      total_time = total_engagement_seconds + overhead_seconds

      return 0.0 if total_time.zero?

      (total_engagement_seconds / total_time) * 100.0
    end

    def infer_purpose(domain, title, category)
      # First try domain-specific keyword matching
      pattern = DOMAIN_PATTERNS[domain&.downcase]

      if pattern
        # Check title keywords for more specific purpose
        pattern[:keywords]&.each do |keywords, purpose|
          return purpose if title&.match?(/#{keywords}/i)
        end

        # Return general purpose for this domain
        return pattern[:purpose]
      end

      # Fallback to category-based inference
      category_to_purpose(category)
    end

    def category_to_purpose(category)
      case category&.to_s
      when /work_/
        :work
      when /learning_/
        :learning
      when /entertainment_/
        :entertainment
      when 'social_media'
        :social_media
      when 'news'
        :news
      when 'shopping'
        :shopping
      when 'reference'
        :reference
      else
        :unknown
      end
    end

    def generate_insight_text(behavior_type:, inferred_purpose:, **vars)
      template = INSIGHT_TEMPLATES.dig(behavior_type, inferred_purpose) ||
                 INSIGHT_TEMPLATES.dig(behavior_type, :default) ||
                 'You visit this resource %<visit_count>s times.'

      format(template, **vars.transform_keys(&:to_sym))
    rescue KeyError => e
      Rails.logger.warn("Missing template variable: #{e.message}")
      "You visit this resource #{vars[:visit_count]} times."
    end

    def generate_suggestion_text(inferred_purpose:, **vars)
      template = SUGGESTION_TEMPLATES[inferred_purpose] ||
                 SUGGESTION_TEMPLATES[:default]

      format(template, **vars.transform_keys(&:to_sym))
    rescue KeyError => e
      Rails.logger.warn("Missing suggestion variable: #{e.message}")
      'Consider using notifications or bookmarks to reduce reopening overhead.'
    end

    def calculate_time_patterns(visits)
      return {} if visits.empty?

      # Group visits by hour of day
      visits_by_hour = visits.group_by { |v| v.visited_at.hour }
      peak_hours = visits_by_hour.sort_by { |_hour, v| -v.size }.first(3).map(&:first)

      # Group by day of week
      visits_by_day = visits.group_by { |v| v.visited_at.strftime('%A') }
      most_active_day = visits_by_day.max_by { |_day, v| v.size }&.first

      # Classify time pattern
      time_pattern = classify_time_pattern(peak_hours)

      {
        peak_hours:,
        most_active_day:,
        time_pattern: time_pattern.to_s
      }
    end

    def classify_time_pattern(peak_hours)
      return :unknown if peak_hours.empty?

      # Work hours: 9am-5pm
      if peak_hours.all? { |hour| hour.between?(9, 17) }
        :work_hours
      # Late night: 10pm-6am
      elsif peak_hours.any? { |hour| hour >= 22 || hour <= 6 }
        :late_night
      # Early morning: 6am-9am
      elsif peak_hours.any? { |hour| hour.between?(6, 9) }
        :early_morning
      # Evening: 5pm-10pm
      elsif peak_hours.any? { |hour| hour.between?(17, 22) }
        :evening
      else
        :mixed
      end
    end
    end
  end
end
