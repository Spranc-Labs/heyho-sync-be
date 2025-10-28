# frozen_string_literal: true

# Background job to refresh personal whitelists by analyzing usage patterns
# Runs daily to detect routine domains and update user's personal whitelist
class RefreshPersonalWhitelistsJob < ApplicationJob
  queue_as :default

  # Refresh whitelist for a specific user
  # @param user_id [Integer] User ID to refresh whitelist for
  def perform(user_id)
    user = User.find(user_id)

    Rails.logger.info("Refreshing personal whitelist for user #{user.id}")

    # Get top domains from last 30 days
    top_domains = get_top_domains(user)

    Rails.logger.info("Analyzing #{top_domains.size} domains for user #{user.id}")

    # Analyze each domain for routine patterns
    top_domains.each do |domain, _visit_count|
      analyze_and_update_whitelist(user, domain)
    end

    # Deactivate stale whitelist entries (domains no longer routine)
    cleanup_stale_entries(user)

    Rails.logger.info("Personal whitelist refresh complete for user #{user.id}")
  end

  private

  def get_top_domains(user)
    # Get domains visited in last 30 days, ordered by visit count
    PageVisit
      .where(user_id: user.id)
      .where('visited_at >= ?', 30.days.ago)
      .group(:domain)
      .count
      .sort_by { |_domain, count| -count }
      .first(20) # Analyze top 20 domains
  end

  def analyze_and_update_whitelist(user, domain)
    # Use RoutineDetector to analyze usage patterns
    result = Insights::RoutineDetector.detect(
      user:,
      domain:,
      lookback_days: 30
    )

    if result[:is_routine]
      # Add or update whitelist entry
      PersonalWhitelist.add_or_update(
        user:,
        domain:,
        reason: result[:routine_type],
        score: result[:score]
      )

      Rails.logger.info(
        "Added #{domain} to whitelist for user #{user.id} " \
        "(score: #{result[:score]}, type: #{result[:routine_type]})"
      )
    else
      # Check if domain was previously whitelisted (and auto-detected)
      existing = PersonalWhitelist.active
        .for_user(user.id)
        .auto_detected
        .find_by(domain:)

      if existing
        # No longer routine - deactivate
        existing.deactivate!
        Rails.logger.info("Deactivated #{domain} for user #{user.id} (no longer routine)")
      end
    end
  end

  def cleanup_stale_entries(user)
    # Find auto-detected entries older than 7 days that haven't been verified recently
    stale_cutoff = 7.days.ago

    stale_entries = PersonalWhitelist.active
      .for_user(user.id)
      .auto_detected
      .where('last_verified_at < ?', stale_cutoff)

    stale_entries.each do |entry|
      # Re-analyze to see if still routine
      result = Insights::RoutineDetector.detect(
        user:,
        domain: entry.domain,
        lookback_days: 30
      )

      if result[:is_routine]
        # Still routine - update verification time
        entry.update!(last_verified_at: Time.current, routine_score: result[:score])
      else
        # No longer routine - deactivate
        entry.deactivate!
        Rails.logger.info("Removed stale entry #{entry.domain} for user #{user.id}")
      end
    end
  end
end
