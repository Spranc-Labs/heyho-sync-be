# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def email_verification(user, token)
    @user = user
    @token = token
    @verification_url = "#{frontend_url}/verify-email?token=#{token}"

    mail(
      to: @user.email,
      subject: I18n.t('mailers.user_mailer.email_verification.subject')
    )
  end

  def password_reset(user, token)
    @user = user
    @token = token
    @reset_url = "#{frontend_url}/reset-password?token=#{token}"

    mail(
      to: @user.email,
      subject: I18n.t('mailers.user_mailer.password_reset.subject')
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
      subject: I18n.t('mailers.user_mailer.email_change_verification.subject')
    )
  end

  def email_change_notification(user, old_email, new_email)
    @user = user
    @new_email = new_email
    @old_email = old_email

    mail(
      to: old_email,
      subject: I18n.t('mailers.user_mailer.email_change_notification.subject')
    )
  end

  private

  def frontend_url
    ENV.fetch('FRONTEND_URL', 'http://localhost:3001')
  end
end
