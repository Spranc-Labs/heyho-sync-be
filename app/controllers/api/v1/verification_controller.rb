# frozen_string_literal: true

module Api
  module V1
    class VerificationController < BaseController
      # POST /api/v1/verify-email
      def verify_email
        email = params[:email]
        code = params[:code]

        if email.blank? || code.blank?
          render_error_response(
            message: 'Email and verification code are required',
            status: :bad_request
          )
          return
        end

        # Find user by email and verify the 6-digit code
        begin
          user = User.find_by(email:)

          if user.nil?
            render_error_response(
              message: 'User not found',
              status: :unprocessable_entity
            )
            return
          end

          # Find the verification record using the user's ID and 6-digit code
          verification_record = ActiveRecord::Base.connection.exec_query(
            'SELECT * FROM user_verification_keys WHERE id = $1 AND key = $2',
            'SQL',
            [user.id, code]
          ).first

          if verification_record
            # Update user to verified status
            user.update!(status: :verified, isVerified: true)

            # Delete verification key
            ActiveRecord::Base.connection.exec_query(
              'DELETE FROM user_verification_keys WHERE id = $1',
              'SQL',
              [user.id]
            )

            render_json_response(
              success: true,
              message: 'Email verified successfully'
            )
          else
            render_error_response(
              message: 'Invalid or expired verification code',
              status: :unprocessable_entity
            )
          end
        rescue StandardError => e
          Rails.logger.error "Email verification error: #{e.message}"
          render_error_response(
            message: 'Verification failed',
            status: :internal_server_error
          )
        end
      end

      # POST /api/v1/resend-verification
      def resend_verification
        email = params[:email]

        if email.blank?
          render_error_response(
            message: 'Email is required',
            status: :bad_request
          )
          return
        end

        begin
          user = User.find_by(email:)

          if user.nil?
            render_error_response(
              message: 'User not found',
              status: :unprocessable_entity
            )
            return
          end

          if user.verified?
            render_error_response(
              message: 'Email is already verified',
              status: :unprocessable_entity
            )
            return
          end

          # Generate new 6-digit verification code
          verification_code = format('%06d', rand(100_000..999_999))

          # Update or create verification record
          existing_record = ActiveRecord::Base.connection.exec_query(
            'SELECT * FROM user_verification_keys WHERE id = $1',
            'SQL',
            [user.id]
          ).first

          if existing_record
            # Update existing record
            ActiveRecord::Base.connection.exec_query(
              'UPDATE user_verification_keys SET key = $1 WHERE id = $2',
              'SQL',
              [verification_code, user.id]
            )
          else
            # Create new record
            ActiveRecord::Base.connection.exec_query(
              'INSERT INTO user_verification_keys (id, key) VALUES ($1, $2)',
              'SQL',
              [user.id, verification_code]
            )
          end

          # Send email with the new 6-digit code
          if Rails.env.development?
            UserMailer.email_verification(user, verification_code).deliver_now
          else
            UserMailer.email_verification(user, verification_code).deliver_later
          end

          render_json_response(
            success: true,
            message: 'Verification code sent successfully',
            data: { verification_code: }  # Remove in production
          )
        rescue StandardError => e
          Rails.logger.error "Resend verification error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render_error_response(
            message: 'Failed to resend verification code',
            status: :internal_server_error
          )
        end
      end
    end
  end
end
