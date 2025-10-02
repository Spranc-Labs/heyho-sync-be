# frozen_string_literal: true

module Authentication
  class PasswordResetService < ::BaseService
    class << self
      def request_reset(email:)
        new(email:).request_reset
      end

      def reset_password(email:, reset_code:, new_password:)
        new(email:, reset_code:, new_password:).reset_password
      end
    end

    def initialize(email: nil, reset_code: nil, new_password: nil)
      super() # BaseService has no state to initialize
      @email = email
      @reset_code = reset_code
      @new_password = new_password
    end

    def request_reset
      return invalid_email_result if email.blank?

      user = find_user
      # Always return success to prevent email enumeration
      send_reset_email_if_user_exists(user) if user

      success_result(
        data: reset_response_data,
        message: 'If an account exists with this email, password reset instructions have been sent'
      )
    rescue StandardError => e
      log_error('Failed to request password reset', e)
      # Still return success for security
      success_result(
        data: reset_response_data,
        message: 'If an account exists with this email, password reset instructions have been sent'
      )
    end

    def reset_password
      return invalid_params_result unless valid_reset_params?

      user = find_user
      return invalid_token_result unless user

      reset_key = find_reset_key(user)
      return invalid_token_result unless reset_key&.valid_for_reset?

      update_user_password!(user, reset_key)

      success_result(
        data: { user: user_data(user) },
        message: 'Password reset successfully'
      )
    rescue StandardError => e
      log_error('Password reset failed', e)
      failure_result(message: 'Password reset failed')
    end

    private

    attr_reader :email, :reset_code, :new_password

    def valid_reset_params?
      email.present? && reset_code.present? && new_password.present?
    end

    def find_user
      User.find_by(email:)
    end

    def find_reset_key(user)
      UserPasswordResetKey.find_for_reset(user.id, reset_code)
    end

    def send_reset_email_if_user_exists(user)
      reset_token = generate_reset_token
      UserPasswordResetKey.create_or_update_for_user(user, reset_token)
      deliver_reset_email(user, reset_token)
      @last_reset_token = reset_token
    end

    def deliver_reset_email(user, token)
      if Rails.env.test?
        UserMailer.password_reset(user, token).deliver_later
      else
        UserMailer.password_reset(user, token).deliver_now
      end
    end

    def update_user_password!(user, reset_key)
      # Use BCrypt to hash the password
      password_hash = BCrypt::Password.create(new_password)
      user.update!(password_hash:)
      reset_key.destroy!
    end

    def generate_reset_token
      SecureRandom.random_number(100_000..999_999).to_s
    end

    def user_data(user)
      {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        isVerified: user.isVerified
      }
    end

    def reset_response_data
      data = {}
      data[:reset_token] = @last_reset_token if show_reset_token?
      data
    end

    def show_reset_token?
      Rails.env.development? || Rails.env.test?
    end

    # Result builders
    def invalid_email_result
      failure_result(message: 'Email is required')
    end

    def invalid_params_result
      failure_result(message: 'Email, reset code, and new password are required')
    end

    def invalid_token_result
      failure_result(message: 'Invalid or expired reset token')
    end
  end
end
