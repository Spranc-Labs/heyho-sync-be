# frozen_string_literal: true

module Insights
  module Analyzers
    # Ranks hoarder tabs by user value, not just hoarder score
    # Prioritizes "forgotten gems" (valuable content) over "noise" (searches, social media)
    class ValueRanker
      # Content type multipliers (how valuable is this type of content?)
      CONTENT_TYPE_WEIGHTS = {
        # High value: Content meant to be consumed
        article: 1.5,
        documentation: 1.5,
        tutorial: 1.5,
        blog_post: 1.4,

        # Medium value: Work-related
        code_review: 1.2,
        issue_tracker: 1.1,
        project_page: 1.0,

        # Low value: Ephemeral/noise
        search_results: 0.7,
        social_media: 0.6,
        news_feed: 0.6,

        # Default
        unknown: 1.0
      }.freeze

      # Age multipliers (older = more likely forgotten)
      AGE_WEIGHTS = {
        very_old: { min: 7.0, multiplier: 1.5 },      # 7+ days: definitely forgotten
        old: { min: 5.0, multiplier: 1.3 },           # 5-7 days: likely forgotten
        medium: { min: 3.0, multiplier: 1.0 },        # 3-5 days: maybe forgotten
        recent: { min: 1.0, multiplier: 0.7 }         # 1-3 days: probably still relevant
      }.freeze

      # Rank hoarder tabs by user value
      # @param tabs [Array<Hash>] Hoarder tabs from HoarderDetectionService
      # @return [Array<Hash>] Tabs with value_rank added, sorted by value descending
      def self.rank(tabs)
        new(tabs).rank
      end

      def initialize(tabs)
        @tabs = tabs
      end

      def rank
        @tabs.map do |tab|
          value_rank = calculate_value_rank(tab)

          tab.merge(
            value_rank:,
            value_breakdown: {
              base_score: tab[:hoarder_score],
              age_weight: age_weight(tab[:tab_age_days]),
              content_weight: content_type_weight(tab),
              final_value: value_rank
            }
          )
        end.sort_by { |tab| -tab[:value_rank] }
      end

      private

      def calculate_value_rank(tab)
        base_score = tab[:hoarder_score] || 0
        age_multiplier = age_weight(tab[:tab_age_days])
        content_multiplier = content_type_weight(tab)

        (base_score * age_multiplier * content_multiplier).round(2)
      end

      # Calculate age weight based on how old the tab is
      def age_weight(age_days)
        return 1.0 if age_days.nil?

        AGE_WEIGHTS.each do |_category, config|
          return config[:multiplier] if age_days >= config[:min]
        end

        0.5 # Less than 1 day: very low value
      end

      # Calculate content type weight based on domain and URL patterns
      def content_type_weight(tab)
        content_type = classify_content_type(tab)
        CONTENT_TYPE_WEIGHTS[content_type] || 1.0
      end

      # Classify content type from domain and URL
      def classify_content_type(tab)
        domain = tab[:domain]
        url = tab[:url] || ''

        # Documentation sites
        return :documentation if documentation_site?(domain, url)

        # Articles/blogs
        return :article if article_site?(domain, url)

        # Code platforms
        return :code_review if code_review?(domain, url)
        return :issue_tracker if issue_tracker?(domain, url)

        # Social media
        return :social_media if social_media_site?(domain)

        # Search results
        return :search_results if search_engine?(domain)

        # News
        return :news_feed if news_site?(domain)

        :unknown
      end

      def documentation_site?(domain, _url)
        domain.match?(/docs\.|developer\.|api\./) ||
          domain.include?('stackoverflow.com') ||
          domain.include?('readthedocs.io')
      end

      def article_site?(domain, url)
        domain.match?(/medium\.com|dev\.to|substack\.com|blog\.|article/) ||
          url.match?(%r{/blog/|/article/|/post/|/tutorial/})
      end

      def code_review?(domain, url)
        (domain.include?('github.com') || domain.include?('gitlab.com')) &&
          url.match?(%r{/(pull|merge_requests)/})
      end

      def issue_tracker?(domain, url)
        (domain.include?('github.com') || domain.include?('gitlab.com')) &&
          url.include?('/issues/')
      end

      def social_media_site?(domain)
        %w[twitter.com x.com facebook.com instagram.com linkedin.com tiktok.com reddit.com].any? do |social|
          domain.include?(social)
        end
      end

      def search_engine?(domain)
        %w[google.com bing.com duckduckgo.com].any? { |engine| domain.include?(engine) } &&
          domain.exclude?('mail.')  # Exclude Gmail
      end

      def news_site?(domain)
        %w[news reddit.com/r/ hackernews nytimes.com cnn.com bbc.com].any? do |news|
          domain.include?(news)
        end
      end
    end
  end
end
