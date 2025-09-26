# frozen_string_literal: true

require 'sequel/core'
require 'jwt'

class RodauthMain < Rodauth::Rails::Auth
  configure do
    # List of authentication features that are loaded.
    enable :create_account, :verify_account, :verify_account_grace_period,
           :login, :logout, :remember, :json,
           :reset_password, :change_password, :change_login, :verify_login_change,
           :close_account

    # See the Rodauth documentation for the list of available config options:
    # http://rodauth.jeremyevans.net/documentation.html

    # ==> General
    # Initialize Sequel and have it reuse Active Record's database connection.
    db Sequel.postgres(extensions: :activerecord_connection, keep_reference: false)
    # Avoid DB query that checks accounts table schema at boot time.
    convert_token_id_to_integer? { User.columns_hash['id'].type == :integer }

    # Change prefix of table and foreign key column names from default "account"
    accounts_table :users
    verify_account_table :user_verification_keys
    verify_login_change_table :user_login_change_keys
    reset_password_table :user_password_reset_keys
    remember_table :user_remember_keys

    # The secret key used for hashing public-facing tokens for various features.
    # Defaults to Rails `secret_key_base`, but you can use your own secret key.
    # hmac_secret "ed5ab3065d130a8ff84173cc3bb7f55a861dd443c6c0c192c5c0b587c3f939ef" \
    #             "478067caee28a7292d8173e3dab077a0ca5c62bac15978b29a573b3bb93dd2b1"

    # JWT tokens are handled manually in login_response

    # Enable JSON-only mode for API
    only_json? true

    # Base URL not needed since UserMailer handles frontend URLs

    # Don't auto-login after account creation - require verification first
    create_account_autologin? false

    # Custom JSON responses
    create_account_notice_flash 'Account created. Please check your email to verify.'

    # Verification success message
    verify_account_notice_flash 'Your account has been verified successfully!'

    # Simple verification success handler
    after_verify_account do
      Rails.logger.info "Account verified successfully for user ID: #{account_id}"
    end

    # JSON response after verification (no redirect in API mode)

    # Handle login and password confirmation fields on the client side.
    require_password_confirmation? false
    require_login_confirmation? false

    # Use path prefix for all routes.
    # prefix "/auth" # Already mounted at /api/v1 in routes.rb

    # Override verify account route to handle both GET and POST
    verify_account_route 'verify-account'

    # Specify the controller used for view rendering, CSRF, and callbacks.
    rails_controller { RodauthController }

    # Make built-in page titles accessible in your views via an instance variable.
    title_instance_variable :@page_title

    # Store account status in an integer column without foreign key constraint.
    account_status_column :status

    # Set account status values explicitly
    account_open_status_value 1 # verified accounts
    account_unverified_status_value 2 # unverified accounts
    account_closed_status_value 3 # closed accounts

    # Store password hash in a column instead of a separate table.
    account_password_hash_column :password_hash

    # Set password when creating account instead of when verifying.
    verify_account_set_password? false

    # Handle Rails timestamps and custom fields manually since Rodauth uses Sequel
    create_account_set_password? true

    # Change some default param keys.
    login_param 'email'
    login_confirm_param 'email-confirm'
    # password_confirm_param "confirm_password"

    # Redirect back to originally requested location after authentication.
    # login_return_to_requested_location? true
    # two_factor_auth_return_to_requested_location? true # if using MFA

    # Autologin the user after they have reset their password.
    # reset_password_autologin? true

    # Delete the account record when the user has closed their account.
    # delete_account_on_close? true

    # Redirect to the app from login and registration pages if already logged in.
    # already_logged_in { redirect login_redirect }

    # ==> Emails - Disable Rodauth emails completely
    send_email do |email|
      # Skip all Rodauth emails - we'll handle them manually
      # This prevents the ActionMailer error
    end

    # Custom create account response with 6-digit verification code
    create_account_response do
      user = User.find(account_id)

      # Generate 6-digit verification code
      verification_code = format('%06d', rand(100_000..999_999))

      # Store the code in the verification key table (replacing the complex key)
      verification_record = db[verify_account_table].where(id: account_id).first
      if verification_record
        # Update the existing record with our 6-digit code
        db[verify_account_table].where(id: account_id).update(key: verification_code)

        # Send email with the 6-digit code
        if Rails.env.development?
          UserMailer.email_verification(user, verification_code).deliver_now
        else
          UserMailer.email_verification(user, verification_code).deliver_later
        end
      end

      # Return JSON response with 6-digit verification code
      response['Content-Type'] = 'application/json'
      response.write({
        success: true,
        message: 'Account created successfully. Please verify your email.',
        verification_code:,
        user: {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          isVerified: user.isVerified
        }
      }.to_json)
      request.halt
    end

    # Custom login response with JWT tokens
    login_response do
      user = User.find(account_id)

      # Generate JWT access token manually with JTI for revocation
      jti = SecureRandom.uuid
      access_token_payload = {
        sub: user.id,
        jti:,
        iss: 'heyho-sync-api',
        aud: 'heyho-sync-app',
        iat: Time.current.to_i,
        exp: Time.current.to_i + 3600,
        scope: 'user'
      }
      access_token = JWT.encode(access_token_payload, Rails.application.secret_key_base, 'HS256')

      # Create ID token with user data
      id_token_payload = {
        type: 'idToken',
        data: {
          user: {
            firstName: user.first_name,
            lastName: user.last_name,
            userId: "user_#{user.id}",
            email: user.email,
            title: '',
            profileUrl: '',
            phone: '',
            organization: '',
            country: ''
          }
        },
        iat: Time.current.to_i,
        exp: Time.current.to_i + 3600
      }

      id_token = JWT.encode(id_token_payload, Rails.application.secret_key_base, 'HS256')

      # Create refresh token (simplified for demo)
      refresh_token = JWT.encode({
                                   user_id: user.id,
                                   iat: Time.current.to_i,
                                   exp: Time.current.to_i + (30 * 24 * 3600) # 30 days
                                 }, Rails.application.secret_key_base, 'HS256')

      response['Content-Type'] = 'application/json'
      response.write({
        statusCode: 200,
        message: 'User logged in successfully',
        error: false,
        data: {
          AccessToken: access_token,
          ExpiresIn: 3600,
          IdToken: id_token,
          RefreshToken: refresh_token,
          TokenType: 'Bearer'
        }
      }.to_json)
      request.halt
    end

    # Custom logout response with JWT revocation
    logout_response do
      # Get the JWT token from Authorization header and revoke it
      auth_header = request.env['HTTP_AUTHORIZATION']
      if auth_header&.start_with?('Bearer ')
        token = auth_header.sub('Bearer ', '')

        begin
          # Decode token to get JTI and user info
          payload = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })[0]
          user = User.find(payload['sub'])

          # Add token to denylist if JTI is present
          if payload['jti']
            JwtDenylist.revoke_jwt(payload, user)
            Rails.logger.info "JWT token #{payload["jti"]} revoked for user #{user.id}"
          end
        rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound => e
          Rails.logger.warn "Failed to revoke JWT during logout: #{e.message}"
          # Continue with logout even if token revocation fails
        end
      end

      response['Content-Type'] = 'application/json'
      response.write({
        statusCode: 200,
        message: 'User logged out successfully',
        error: false
      }.to_json)
      request.halt
    end

    # ==> Flash
    # Override default flash messages.
    # create_account_notice_flash "Your account has been created. Please verify your account " \
    #                             "by visiting the confirmation link sent to your email address."
    # require_login_error_flash "Login is required for accessing this page"
    # login_notice_flash nil

    # ==> Validation
    # Override default validation error messages.
    # no_matching_login_message "user with this email address doesn't exist"
    # already_an_account_with_this_login_message "user with this email address already exists"
    # password_too_short_message { "needs to have at least #{password_minimum_length} characters" }
    # login_does_not_meet_requirements_message do
    #   "invalid email#{", #{login_requirement_message}" if login_requirement_message}"
    # end

    # Passwords shorter than 8 characters are considered weak according to OWASP.
    password_minimum_length 8
    # bcrypt has a maximum input length of 72 bytes, truncating any extra bytes.
    password_maximum_bytes 72

    # Custom password complexity requirements (alternative to password_complexity feature).
    # password_meets_requirements? do |password|
    #   super(password) && password_complex_enough?(password)
    # end
    # auth_class_eval do
    #   def password_complex_enough?(password)
    #     return true if password.match?(/\d/) && password.match?(/[^a-zA-Z\d]/)
    #     set_password_requirement_error_message(:password_simple, "requires one number and one special character")
    #     false
    #   end
    # end

    # ==> Remember Feature
    # Remember all logged in users.
    after_login { remember_login }

    # Or only remember users that have ticked a "Remember Me" checkbox on login.
    # after_login { remember_login if param_or_nil("remember") }

    # Extend user's remember period when remembered via a cookie
    extend_remember_deadline? true

    # ==> Hooks
    # Validate custom fields in the create account form.
    before_create_account do
      throw_error_status(422, 'first_name', 'must be present') if param('first_name').blank?
      throw_error_status(422, 'last_name', 'must be present') if param('last_name').blank?

      # Set timestamps and custom fields
      now = Time.current
      account.merge!(
        created_at: now,
        updated_at: now,
        first_name: param('first_name'),
        last_name: param('last_name')
      )
    end

    # Let Rodauth handle account updates normally

    # Perform additional actions after the account is created.
    # after_create_account do
    #   Profile.create!(account_id: account_id, name: param("name"))
    # end

    # Do additional cleanup after the account is closed.
    # after_close_account do
    #   Profile.find_by!(account_id: account_id).destroy
    # end

    # ==> Deadlines
    # Change default deadlines for some actions.
    # verify_account_grace_period 3.days.to_i
    # reset_password_deadline_interval Hash[hours: 6]
    # verify_login_change_deadline_interval Hash[days: 2]
    # remember_deadline_interval Hash[days: 30]
  end
end
