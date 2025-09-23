# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def email_verification(user, token)
    @user = user
    @token = token
    @verification_url = "#{frontend_url}/verify-email?token=#{token}"

    mail(
      to: @user.email,
      subject: 'Verify your HeyHo Sync account'
    )
  end

  def password_reset(user, token)
    @user = user
    @token = token
    @reset_url = "#{frontend_url}/reset-password?token=#{token}"

    mail(
      to: @user.email,
      subject: 'Reset your HeyHo Sync password'
    )
  end

  def email_change_verification(user, token)
    @user = user
    @new_email = user.pending_email
    @old_email = user.email
    @token = token
    @email_change_url = "#{frontend_url}/confirm-email-change?token=#{token}"

    mail(
      to: @new_email,
      subject: 'Verify your new email for HeyHo Sync'
    )
  end

  def email_change_notification(user, old_email, new_email)
    @user = user
    @new_email = new_email
    @old_email = old_email

    mail(
      to: old_email,
      subject: 'Email change requested for your HeyHo Sync account'
    )
  end

  private

  def frontend_url
    ENV['FRONTEND_URL'] || 'http://localhost:3001'
  end
end
