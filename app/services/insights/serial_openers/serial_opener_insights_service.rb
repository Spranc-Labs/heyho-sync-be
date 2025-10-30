# frozen_string_literal: true

module Insights
  module SerialOpeners
    # Main orchestration service for serial opener insights with time-based analysis
    # Combines detection, insight generation, and trend comparison
    class SerialOpenerInsightsService < BaseService
      include DateRangeHelper

      def initialize(user:, period: nil, start_date: nil, end_date: nil, include_comparison: false)
        super()
        @user = user
        @period = period
        @start_date = start_date
        @end_date = end_date
        @include_comparison = include_comparison
      end

      def call
        # Parse date range
        date_range = parse_date_range(period: @period, start_date: @start_date, end_date: @end_date)
        days = days_in_range(date_range)

        # Create adaptive threshold calculator for this period
        calculator = Insights::Calculators::AdaptiveThresholdCalculator.new(days_in_period: days)

        # Detect serial openers for current period
        current_openers = detect_serial_openers_for_period(date_range, calculator)

        # Enrich with insights
        enriched_openers = enrich_with_insights(current_openers, calculator, date_range)

        # Build response
        response_data = {
          period: date_range[:period],
          date_range: {
            start: date_range[:start].to_date.to_s,
            end: date_range[:end].to_date.to_s,
            days: days.round(1)
          },
          serial_openers: enriched_openers,
          count: enriched_openers.size,
          criteria: {
            min_visits_per_day: calculator.min_visits_per_day_threshold,
            effective_min_visits: (calculator.min_visits_per_day_threshold * days).round,
            max_total_engagement_seconds: calculator.max_serial_opener_engagement_seconds
          }
        }

        # Add comparison if requested
        if @include_comparison
          comparison = calculate_comparison(date_range, calculator, enriched_openers)
          response_data[:comparison] = comparison if comparison
        end

        success_result(data: response_data)
      rescue ArgumentError => e
        failure_result(message: 'Invalid parameters', errors: [e.message])
      rescue StandardError => e
        log_error("Serial opener insights failed for user #{@user.id}: #{e.message}", e)
        failure_result(message: 'Failed to generate insights', errors: [e.message])
      end

      private

      attr_reader :user

      def detect_serial_openers_for_period(date_range, calculator)
        days = days_in_range(date_range)

        Detections::SerialOpenerDetectionService.call(
          user,
          days_in_period: days,
          max_total_engagement: calculator.max_serial_opener_engagement_seconds,
          start_date: date_range[:start],
          end_date: date_range[:end]
        )
      end

      def enrich_with_insights(openers, calculator, date_range)
        generator = SerialOpenerInsightGenerator.new(calculator:)

        openers.map do |opener|
          # Fetch individual visits for time pattern analysis
          visits = fetch_visits_for_opener(opener, date_range)

          # Generate enriched insights
          generator.generate_insights(opener, visits)
        end
      end

      def fetch_visits_for_opener(opener, date_range)
        # Use the normalized URL to match visits, with proper escaping for LIKE queries
        # For domains like Gmail where normalized_url has no path, match by domain prefix
        normalized_url = opener[:normalized_url]

        # Escape special LIKE characters (%, _)
        escaped_url = normalized_url.gsub(/[%_]/, '\\\\\&')

        PageVisit
          .where(user_id: user.id)
          .where('visited_at >= ? AND visited_at <= ?', date_range[:start], date_range[:end])
          .where('url LIKE ?', "#{escaped_url}%")
          .select(:visited_at)
          .limit(1000) # Safety limit to prevent memory issues
          .to_a
      end

      def calculate_comparison(current_range, calculator, current_openers)
        # Get previous period range
        previous_range = previous_period_range(current_range)
        Rails.logger.info("🔍 Previous period range: #{previous_range[:start]} to #{previous_range[:end]}")

        # Detect serial openers for previous period
        previous_openers = detect_serial_openers_for_period(previous_range, calculator)
        Rails.logger.info("🔍 Found #{previous_openers.size} serial openers in previous period")

        # Enrich previous openers with insights for comparison
        enriched_previous = enrich_with_insights(previous_openers, calculator, previous_range)
        Rails.logger.info("🔍 Enriched #{enriched_previous.size} previous period openers")

        # Calculate comparison
        comparison_data = Insights::Calculators::ComparisonCalculator.calculate(current_openers, enriched_previous)
        Rails.logger.info('🔍 Comparison calculated successfully')

        # Add previous period metadata
        comparison_data.merge(
          previous_period: {
            start: previous_range[:start].to_date.to_s,
            end: previous_range[:end].to_date.to_s,
            count: enriched_previous.size
          }
        )
      rescue StandardError => e
        log_error("❌ Comparison calculation failed: #{e.message}", e)
        Rails.logger.error("❌ Full error: #{e.class.name}: #{e.message}")
        Rails.logger.error("❌ Backtrace: #{e.backtrace.first(5).join("\n")}")
        nil # Return nil if comparison fails, don't fail the whole request
      end
    end
  end
end
