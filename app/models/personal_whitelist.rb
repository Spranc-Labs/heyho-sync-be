# frozen_string_literal: true

# Stores user-specific domain whitelists learned from usage patterns
# Domains in active whitelist are excluded from hoarder tab detection
class PersonalWhitelist < ApplicationRecord
  # Whitelist reasons
  REASONS = %w[
    work_tool
    entertainment_routine
    reference
    manual
    routine_site
  ].freeze

  # Strong whitelist: NEVER flag, no matter what (email, calendars)
  STRONG_WHITELIST_REASONS = %w[work_tool manual].freeze

  # Conditional whitelist: Usually exclude, but flag if severe hoarder pattern
  # (entertainment sites, content platforms where specific tabs can be hoarders)
  CONDITIONAL_WHITELIST_REASONS = %w[entertainment_routine reference routine_site].freeze

  # Associations
  belongs_to :user

  # Validations
  validates :domain, presence: true
  validates :whitelist_reason, inclusion: { in: REASONS, allow_nil: true }
  validates :domain, uniqueness: { scope: %i[user_id is_active], conditions: -> { where(is_active: true) } }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :for_user, ->(user_id) { where(user_id:) }
  scope :by_reason, ->(reason) { where(whitelist_reason: reason) }
  scope :auto_detected, -> { where.not(whitelist_reason: 'manual') }
  scope :manual, -> { where(whitelist_reason: 'manual') }

  # Check if a domain is whitelisted for a user (supports subdomains)
  # @param user [User] User to check
  # @param domain [String] Domain to check
  # @return [Boolean] True if domain is in active whitelist
  def self.whitelisted?(user:, domain:)
    find_for(user:, domain:).present?
  end

  # Get whitelist entry for a domain (supports subdomains)
  # @param user [User] User to check
  # @param domain [String] Domain to check
  # @return [PersonalWhitelist, nil] Whitelist entry or nil
  # @example
  #   If youtube.com is whitelisted, music.youtube.com will also match
  def self.find_for(user:, domain:)
    # First try exact match
    entry = active.for_user(user.id).find_by(domain:)
    return entry if entry

    # Try subdomain match: check if domain ends with any whitelisted domain
    # e.g., music.youtube.com matches youtube.com
    whitelisted_domains = active.for_user(user.id).pluck(:domain)
    whitelisted_domains.each do |whitelisted_domain|
      # Check if current domain is a subdomain of whitelisted domain
      if domain.end_with?(".#{whitelisted_domain}") || domain == whitelisted_domain
        return active.for_user(user.id).find_by(domain: whitelisted_domain)
      end
    end

    nil
  end

  # Add or update whitelist entry
  # @param user [User] User
  # @param domain [String] Domain to whitelist
  # @param reason [String] Whitelist reason
  # @param score [Integer] Routine score (for auto-detected)
  # @return [PersonalWhitelist] Created or updated whitelist entry
  def self.add_or_update(user:, domain:, reason:, score: nil)
    entry = for_user(user.id).find_or_initialize_by(domain:)

    entry.assign_attributes(
      whitelist_reason: reason,
      routine_score: score,
      detected_at: entry.new_record? ? Time.current : entry.detected_at,
      last_verified_at: Time.current,
      is_active: true
    )

    entry.save!
    entry
  end

  # Deactivate whitelist entry (soft delete)
  def deactivate!
    update!(is_active: false)
  end

  # Reactivate whitelist entry
  def reactivate!
    update!(is_active: true, last_verified_at: Time.current)
  end

  # Check if this is a conditional whitelist (can be overridden for severe hoarders)
  # @return [Boolean] True if conditional, false if strong whitelist
  def conditional_whitelist?
    CONDITIONAL_WHITELIST_REASONS.include?(whitelist_reason)
  end

  # Check if this is a strong whitelist (never override)
  # @return [Boolean] True if strong whitelist
  def strong_whitelist?
    STRONG_WHITELIST_REASONS.include?(whitelist_reason)
  end
end
