# frozen_string_literal: true

class User < ApplicationRecord
  include Rodauth::Rails.model

  # Validations are handled by Rodauth for auth-related fields
  # validates :first_name, presence: true, allow_blank: false
  # validates :last_name, presence: true, allow_blank: false
  # validates :email, presence: true, uniqueness: true

  # Status enum for Rodauth compatibility
  enum status: { verified: 1, unverified: 2, closed: 3 }

  # Keep isVerified as the primary field, sync with status
  before_save :sync_status_with_is_verified

  def verified?
    isVerified
  end

  def unverified?
    !isVerified
  end

  # Override isVerified= to sync with status
  def isVerified=(value)
    super(value)
    self.status = value ? :verified : :unverified
  end

  private

  def sync_status_with_is_verified
    # Sync status based on isVerified when saving
    if isVerified_changed?
      self.status = isVerified? ? :verified : :unverified
    elsif status_changed?
      # If status is changed directly, sync isVerified
      self.isVerified = verified?
    end
  end
end
