# frozen_string_literal: true

module Authentication
  class EmailVerificationService < ::BaseService
    class << self
      def verify_email(email:, code:)
        new(email:, code:).verify
      end

      def resend_verification(email:)
        new(email:).resend
      end
    end

    def initialize(email: nil, code: nil)
      super() # BaseService has no state to initialize
      @email = email
      @code = code
    end

    def verify
      return invalid_params_result unless valid_verification_params?

      user = find_user
      return user_not_found_result unless user

      verification = find_verification(user)
      return invalid_code_result unless verification

      verify_user!(user, verification)
      success_result(data: user, message: 'Email verified successfully')
    rescue StandardError => e
      log_error('Email verification failed', e)
      failure_result(message: 'Verification failed')
    end

    def resend
      return invalid_email_result if email.blank?

      user = find_user
      return user_not_found_result unless user
      return already_verified_result if user.verified?

      send_verification_to(user)
      success_result(data: verification_response_data(user), message: 'Verification email sent successfully')
    rescue StandardError => e
      log_error('Failed to resend verification', e)
      failure_result(message: 'Failed to resend verification code')
    end

    private

    attr_reader :email, :code

    def valid_verification_params?
      email.present? && code.present?
    end

    def find_user
      User.find_by(email:)
    end

    def find_verification(user)
      UserVerificationKey.find_for_verification(user.id, code)
    end

    def verify_user!(user, verification)
      user.update!(status: :verified, isVerified: true)
      verification.destroy!
    end

    def send_verification_to(user)
      verification_code = generate_verification_code
      UserVerificationKey.create_or_update_for_user(user, verification_code)
      deliver_verification_email(user, verification_code)
      @last_verification_code = verification_code
    end

    def deliver_verification_email(user, code)
      if Rails.env.test?
        UserMailer.email_verification(user, code).deliver_later
      else
        UserMailer.email_verification(user, code).deliver_now
      end
    end

    def verification_response_data(_user)
      data = { message: 'Verification email sent' }
      data[:verification_code] = @last_verification_code if show_verification_code?
      data
    end

    def show_verification_code?
      Rails.env.development? || Rails.env.test?
    end

    def generate_verification_code
      SecureRandom.random_number(100_000..999_999).to_s
    end

    # Result builders
    def invalid_params_result
      failure_result(message: 'Email and verification code are required')
    end

    def invalid_email_result
      failure_result(message: 'Email is required')
    end

    def user_not_found_result
      failure_result(message: 'User not found')
    end

    def invalid_code_result
      failure_result(message: 'Invalid or expired verification code')
    end

    def already_verified_result
      failure_result(message: 'Email is already verified')
    end
  end
end
