# frozen_string_literal: true

module Insights
  module Analyzers
    # Provides context-aware domain classification for smarter hoarder detection
    # Distinguishes between productivity tools, content sites, and work-related tabs
    class DomainContextAnalyzer
      # Universal whitelist: These domains are NEVER flagged as hoarder tabs
      # (Email, calendars - core productivity tools everyone uses)
      UNIVERSAL_WHITELIST = %w[
        mail.google.com
        gmail.com
        calendar.google.com
        outlook.com
        outlook.live.com
      ].freeze

      # Domains that are typically productivity tools (email, calendars, task managers)
      PRODUCTIVITY_TOOLS = %w[
        mail.google.com
        gmail.com
        outlook.com
        calendar.google.com
        notion.so
        slack.com
        discord.com
        teams.microsoft.com
        todoist.com
        trello.com
        asana.com
        linear.app
        figma.com
        miro.com
      ].freeze

      # Domains that typically host content meant to be read/consumed
      CONTENT_SITES = %w[
        medium.com
        dev.to
        substack.com
        news.ycombinator.com
        reddit.com
        twitter.com
        x.com
        youtube.com
        vimeo.com
        instagram.com
      ].freeze

      # Code platforms (special handling: PRs/issues = work, random repos = potential hoarder)
      CODE_PLATFORMS = %w[
        github.com
        gitlab.com
        bitbucket.org
      ].freeze

      # Documentation sites (context-dependent: frequently revisited = reference, single visit = hoarder)
      DOCUMENTATION_SITES = [
        'stackoverflow.com',
        'docs.', # Matches docs.* (e.g., docs.python.org, docs.ruby-lang.org)
        'developer.', # Matches developer.* (e.g., developer.mozilla.org)
        'api.', # API documentation
        'readthedocs.io'
      ].freeze

      # Analyze domain context and return classification with hoarder detection rules
      # @param user [User] User for checking personal whitelist
      # @param domain [String] The domain to analyze
      # @param url [String] Full URL for additional context
      # @param tab_metadata [Hash] Tab metadata from TabAgeCalculator
      # @return [Hash] Domain context and detection rules
      def self.analyze(user:, domain:, url:, tab_metadata:)
        new(user:, domain:, url:, tab_metadata:).analyze
      end

      def initialize(user:, domain:, url:, tab_metadata:)
        @user = user
        @domain = domain
        @url = url
        @tab_metadata = tab_metadata
      end

      def analyze
        whitelist_status = check_whitelist

        {
          domain_type: classify_domain,
          is_whitelisted: whitelist_status[:is_whitelisted],
          whitelist_reason: whitelist_status[:reason],
          is_conditional_whitelist: whitelist_status[:is_conditional],
          should_apply_strict_rules: strict_rules?,
          should_apply_lenient_rules: lenient_rules?,
          context_notes: generate_context_notes
        }
      end

      private

      def classify_domain
        return :productivity_tool if productivity_tool?
        return :content_site if content_site?
        return :code_platform if code_platform?
        return :documentation if documentation_site?

        :general
      end

      def productivity_tool?
        PRODUCTIVITY_TOOLS.any? { |tool| @domain == tool || @domain.end_with?(".#{tool}") }
      end

      def content_site?
        CONTENT_SITES.any? { |site| @domain == site || @domain.end_with?(".#{site}") }
      end

      def code_platform?
        CODE_PLATFORMS.any? { |platform| @domain == platform || @domain.end_with?(".#{platform}") }
      end

      def documentation_site?
        DOCUMENTATION_SITES.any? do |doc_pattern|
          # Handle both exact matches and prefix patterns (e.g., 'docs.', 'api.')
          if doc_pattern.end_with?('.')
            @domain.start_with?(doc_pattern)
          else
            @domain == doc_pattern || @domain.end_with?(".#{doc_pattern}")
          end
        end
      end

      # Strict rules: More likely to be hoarders (content sites, single-visit docs)
      def strict_rules?
        return true if content_site? && @tab_metadata[:is_single_visit]
        return true if documentation_site? && @tab_metadata[:is_single_visit]
        return true if code_platform? && looks_like_random_repo?

        false
      end

      # Lenient rules: Less likely to be hoarders (productivity tools with recent activity)
      def lenient_rules?
        # Productivity tools with recent activity should not be flagged
        return true if productivity_tool? && recent_activity?

        # Code platforms with PR/issue URLs are likely active work
        return true if code_platform? && looks_like_active_work?

        # Documentation with frequent revisits is likely a reference
        return true if documentation_site? && frequent_revisits?

        false
      end

      def recent_activity?
        @tab_metadata[:days_since_last_activity] < 1.0 # Activity within last 24 hours
      end

      def frequent_revisits?
        @tab_metadata[:visit_count] >= 3 # Visited 3+ times
      end

      def looks_like_active_work?
        # GitHub/GitLab PRs, issues, and project repositories
        @url.match?(%r{/(pull|issues|commits|compare)/}) ||
          @url.match?(%r{/projects/\d+/(merge_requests|issues)})
      end

      def looks_like_random_repo?
        # Generic repository page without specific work indicators
        code_platform? &&
          !looks_like_active_work? &&
          @tab_metadata[:is_single_visit]
      end

      # Check if domain is whitelisted (universal only)
      def check_whitelist
        # Check universal whitelist (always strong whitelist)
        return { is_whitelisted: true, reason: 'universal_whitelist', is_conditional: false } if universal_whitelist?

        # Personal whitelist feature disabled for now
        # TODO: Re-enable when personal whitelist feature is implemented

        # Not whitelisted
        { is_whitelisted: false, reason: nil, is_conditional: false }
      end

      def universal_whitelist?
        UNIVERSAL_WHITELIST.any? do |whitelisted_domain|
          # Exact match or subdomain match
          @domain == whitelisted_domain || @domain.end_with?(".#{whitelisted_domain}")
        end
      end

      def generate_context_notes
        notes = []

        if productivity_tool?
          notes << if recent_activity?
                     'Productivity tool with recent activity - likely intentional'
                   else
                     'Productivity tool with no recent activity - possible forgotten tab'
                   end
        end

        if content_site? && @tab_metadata[:is_single_visit]
          notes << 'Content site visited once - classic "read later" pattern'
        end

        if documentation_site?
          notes << if frequent_revisits?
                     'Frequently revisited documentation - likely a reference'
                   else
                     'Documentation visited once - possible unread article'
                   end
        end

        if code_platform?
          if looks_like_active_work?
            notes << 'Active work (PR/issue) - should not be flagged'
          elsif looks_like_random_repo?
            notes << 'Random repository visit - potential hoarder'
          end
        end

        notes.join('; ')
      end
    end
  end
end
