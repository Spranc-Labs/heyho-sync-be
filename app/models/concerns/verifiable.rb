# frozen_string_literal: true

module Verifiable
  extend ActiveSupport::Concern

  included do
    # Status enum for Rodauth compatibility
    enum status: { verified: 1, unverified: 2, closed: 3 }

    # Keep isVerified as the primary field, sync with status
    before_save :sync_status_with_is_verified
  end

  def verified?
    isVerified
  end

  def can_be_verified?
    !verified?
  end

  def verify!
    update!(
      status: :verified,
      isVerified: true
    )
  end

  def verification_pending?
    !verified?
  end

  private

  def sync_status_with_is_verified
    if isVerified_changed?
      # If isVerified is changed, sync status
      self.status = isVerified? ? :verified : :unverified
    elsif status_changed?
      # If status is changed directly, sync isVerified
      self.isVerified = verified?
    end
  end
end
