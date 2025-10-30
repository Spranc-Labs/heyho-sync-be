# frozen_string_literal: true

module Insights
  module Calculators
    # Calculates comparisons between current and previous period serial openers
    # Provides trend analysis and change detection
    class ComparisonCalculator
      SIGNIFICANT_CHANGE_THRESHOLD = 20.0 # 20% change is considered significant

      # Compare current and previous period data
      # @param current_openers [Array<Hash>] Serial openers from current period
      # @param previous_openers [Array<Hash>] Serial openers from previous period
      # @return [Hash] Comparison data with trends and changes
      def self.calculate(current_openers, previous_openers)
        new.calculate(current_openers, previous_openers)
      end

      def calculate(current_openers, previous_openers)
        # Build lookup maps by normalized URL
        current_map = build_opener_map(current_openers)
        previous_map = build_opener_map(previous_openers)

        # Overall statistics
        overall_comparison = calculate_overall_comparison(current_openers, previous_openers)

        # Per-resource comparisons
        resource_comparisons = calculate_resource_comparisons(current_map, previous_map)

        # Identify behavioral changes
        behavioral_changes = identify_behavioral_changes(current_map, previous_map)

        {
          overall: overall_comparison,
          by_resource: resource_comparisons,
          behavioral_changes:,
          summary: generate_summary(overall_comparison, behavioral_changes)
        }
      end

      private

      def build_opener_map(openers)
        openers.each_with_object({}) do |opener, map|
          key = opener[:normalized_url] || opener[:url]
          map[key] = opener
        end
      end

      def calculate_overall_comparison(current_openers, previous_openers)
        current_total_visits = current_openers.sum { |o| o[:visit_count] }
        previous_total_visits = previous_openers.sum { |o| o[:visit_count] }

        current_total_engagement = current_openers.sum { |o| o[:total_engagement_seconds] }
        previous_total_engagement = previous_openers.sum { |o| o[:total_engagement_seconds] }

        {
          total_serial_openers: {
            current: current_openers.size,
            previous: previous_openers.size,
            change: current_openers.size - previous_openers.size,
            percent_change: calculate_percent_change(current_openers.size, previous_openers.size),
            trend: calculate_trend(current_openers.size, previous_openers.size)
          },
          total_visits: {
            current: current_total_visits,
            previous: previous_total_visits,
            change: current_total_visits - previous_total_visits,
            percent_change: calculate_percent_change(current_total_visits, previous_total_visits),
            trend: calculate_trend(current_total_visits, previous_total_visits)
          },
          total_engagement_seconds: {
            current: current_total_engagement,
            previous: previous_total_engagement,
            change: current_total_engagement - previous_total_engagement,
            percent_change: calculate_percent_change(current_total_engagement, previous_total_engagement),
            trend: calculate_trend(current_total_engagement, previous_total_engagement)
          }
        }
      end

      def calculate_resource_comparisons(current_map, previous_map)
        all_urls = (current_map.keys + previous_map.keys).uniq
        comparisons = []

        all_urls.each do |url|
          current = current_map[url]
          previous = previous_map[url]

          comparison = build_resource_comparison(url, current, previous)
          comparisons << comparison if comparison[:status] != :unchanged
        end

        # Sort by significance of change
        comparisons.sort_by { |c| -c[:visit_count_change].abs }
      end

      def build_resource_comparison(url, current, previous)
        if current && previous
          # Resource exists in both periods
          {
            url:,
            title: current[:title],
            domain: current[:domain],
            status: :continued,
            visit_count_change: current[:visit_count] - previous[:visit_count],
            visit_count_percent_change: calculate_percent_change(current[:visit_count], previous[:visit_count]),
            engagement_change: current[:total_engagement_seconds] - previous[:total_engagement_seconds],
            behavior_type_current: current[:behavior_type],
            behavior_type_previous: previous[:behavior_type],
            behavior_changed: current[:behavior_type] != previous[:behavior_type]
          }
        elsif current
          # New serial opener in current period
          {
            url:,
            title: current[:title],
            domain: current[:domain],
            status: :new,
            visit_count: current[:visit_count],
            visit_count_change: current[:visit_count], # Positive change (from 0)
            behavior_type: current[:behavior_type],
            insight: 'New pattern emerged this period'
          }
        else
          # Serial opener from previous period no longer present
          {
            url:,
            title: previous[:title],
            domain: previous[:domain],
            status: :resolved,
            previous_visit_count: previous[:visit_count],
            visit_count_change: -previous[:visit_count], # Negative change (to 0)
            insight: 'No longer a serial opener - pattern improved!'
          }
        end
      end

      def identify_behavioral_changes(current_map, previous_map)
        changes = []

        current_map.each do |url, current|
          previous = previous_map[url]
          next unless previous

          # Check if behavior classification changed
          current_behavior = current[:behavior_type]
          previous_behavior = previous[:behavior_type]

          next if current_behavior == previous_behavior

          changes << {
            url:,
            title: current[:title],
            domain: current[:domain],
            from: previous_behavior,
            to: current_behavior,
            direction: behavior_change_direction(previous_behavior, current_behavior),
            visit_count_change: current[:visit_count] - previous[:visit_count]
          }
        end

        changes.sort_by { |c| behavior_severity_score(c[:to]) }.reverse
      end

      def generate_summary(overall, behavioral_changes)
        messages = []

        # Overall trend
        visits_trend = overall[:total_visits][:trend]
        messages << case visits_trend
                    when :increasing
                      "Serial opener activity increased by #{overall[:total_visits][:percent_change].abs.round}%"
                    when :decreasing
                      "Serial opener activity decreased by #{overall[:total_visits][:percent_change].abs.round}% - improvement!"
                    else
                      'Serial opener activity remained stable'
                    end

        # Behavioral changes
        if behavioral_changes.any?
          worsened = behavioral_changes.count { |c| c[:direction] == :worsened }
          improved = behavioral_changes.count { |c| c[:direction] == :improved }

          messages << "#{worsened} resources worsened" if worsened.positive?
          messages << "#{improved} resources improved" if improved.positive?
        end

        messages.join('. ')
      end

      def calculate_percent_change(current, previous)
        return 0.0 if current.zero? && previous.zero? # Both zero = no change
        return 100.0 if current.positive? && previous.zero? # New activity = 100% increase
        return -100.0 if current.zero? && previous.positive?  # Activity stopped = 100% decrease

        ((current - previous).to_f / previous * 100.0).round(1)
      end

      def calculate_trend(current, previous)
        percent = calculate_percent_change(current, previous)

        if percent > SIGNIFICANT_CHANGE_THRESHOLD
          :increasing
        elsif percent < -SIGNIFICANT_CHANGE_THRESHOLD
          :decreasing
        else
          :stable
        end
      end

      def behavior_change_direction(from, to)
        from_score = behavior_severity_score(from)
        to_score = behavior_severity_score(to)

        if to_score > from_score
          :worsened
        elsif to_score < from_score
          :improved
        else
          :unchanged
        end
      end

      def behavior_severity_score(behavior_type)
        case behavior_type.to_s
        when 'compulsive_checking'
          4
        when 'frequent_monitoring'
          3
        when 'regular_reference'
          2
        when 'periodic_revisit'
          1
        else
          0
        end
      end
    end
  end
end
