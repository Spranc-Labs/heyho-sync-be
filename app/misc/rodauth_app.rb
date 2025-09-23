class RodauthApp < Rodauth::Rails::App
  # primary configuration
  configure RodauthMain

  # secondary configuration
  # configure RodauthAdmin, :admin

  route do |r|
    rodauth.load_memory # autologin remembered users

    # Custom verify-email route to match expected endpoint
    r.post 'verify-email' do
      email = r.params['email']
      code = r.params['code']

      if email.blank? || code.blank?
        response.status = 400
        { error: 'Email and verification code are required' }
      else
        begin
          user = User.find_by(email:)

          if user.nil?
            response.status = 422
            { error: 'User not found' }
          else
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

              { success: true, message: 'Email verified successfully' }
            else
              response.status = 422
              { error: 'Invalid or expired verification code' }
            end
          end
        rescue StandardError => e
          Rails.logger.error "Email verification error: #{e.message}"
          response.status = 500
          { error: 'Verification failed' }
        end
      end
    end

    r.rodauth # route rodauth requests

    # ==> Authenticating requests
    # Call `rodauth.require_account` for requests that you want to
    # require authentication for. For example:
    #
    # # authenticate /dashboard/* and /account/* requests
    # if r.path.start_with?("/dashboard") || r.path.start_with?("/account")
    #   rodauth.require_account
    # end

    # ==> Secondary configurations
    # r.rodauth(:admin) # route admin rodauth requests
  end
end
