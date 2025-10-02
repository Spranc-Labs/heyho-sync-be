# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Password Reset API' do
  let!(:user) do
    User.create!(
      email: 'test@example.com',
      password_hash: BCrypt::Password.create('OldPassword123!'),
      first_name: 'John',
      last_name: 'Doe',
      status: :verified,
      isVerified: true
    )
  end
  let(:reset_code) { '123456' }

  describe 'POST /api/v1/reset-password-request' do
    context 'with existing user email' do
      it 'sends password reset email and returns success' do
        expect do
          post '/api/v1/reset-password-request', params: { email: user.email }, as: :json
        end.to have_enqueued_mail(UserMailer, :password_reset)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(
          'success' => true,
          'message' => 'If an account exists with this email, password reset instructions have been sent'
        )

        # Should contain reset code in development/test
        expect(response.parsed_body['data']['reset_token']).to match(/\A\d{6}\z/)
      end

      it 'creates password reset key in database' do
        post '/api/v1/reset-password-request', params: { email: user.email }, as: :json

        reset_key = UserPasswordResetKey.find_by(id: user.id)
        expect(reset_key).to be_present
        expect(reset_key.key).to be_present
        expect(reset_key.deadline).to be > Time.current
      end

      it 'updates existing password reset key' do
        # Create initial reset key
        UserPasswordResetKey.create!(
          id: user.id,
          key: '111111',
          deadline: 1.hour.from_now
        )

        post '/api/v1/reset-password-request', params: { email: user.email }, as: :json

        reset_key = UserPasswordResetKey.find_by(id: user.id)
        expect(reset_key.key).not_to eq('111111')
        expect(reset_key.key).to match(/\A\d{6}\z/)
      end
    end

    context 'with non-existent user email' do
      it 'returns success to prevent email enumeration' do
        expect do
          post '/api/v1/reset-password-request', params: { email: 'nonexistent@example.com' }, as: :json
        end.not_to have_enqueued_mail

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(
          'success' => true,
          'message' => 'If an account exists with this email, password reset instructions have been sent'
        )
      end

      it 'does not create password reset key' do
        post '/api/v1/reset-password-request', params: { email: 'nonexistent@example.com' }, as: :json

        reset_keys_count = UserPasswordResetKey.count
        expect(reset_keys_count).to eq(0)
      end
    end

    context 'with missing email' do
      it 'returns error for missing email' do
        post '/api/v1/reset-password-request', params: {}, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['message']).to include('Email is required')
      end
    end

    context 'with server errors' do
      it 'still returns success for security' do
        allow(User).to receive(:find_by).and_raise(StandardError.new('Database error'))

        post '/api/v1/reset-password-request', params: { email: user.email }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(
          'success' => true,
          'message' => 'If an account exists with this email, password reset instructions have been sent'
        )
      end
    end
  end

  describe 'POST /api/v1/reset-password' do
    before do
      # Create password reset key
      UserPasswordResetKey.create!(
        id: user.id,
        key: reset_code,
        deadline: 1.hour.from_now,
        email_last_sent: Time.current
      )
    end

    context 'with valid reset token and password' do
      it 'resets password successfully' do
        reset_params = {
          email: user.email,
          reset_code: reset_code,
          new_password: 'NewPassword456!'
        }

        post '/api/v1/reset-password', params: reset_params, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(
          'success' => true,
          'message' => 'Password reset successfully'
        )
        expect(response.parsed_body['data']['user']['email']).to eq(user.email)

        # Verify password was updated
        user.reload
        expect(user.valid_password?('NewPassword456!')).to be true
        expect(user.valid_password?('OldPassword123!')).to be false
      end

      it 'deletes reset token after successful reset' do
        reset_params = {
          email: user.email,
          reset_code: reset_code,
          new_password: 'NewPassword456!'
        }

        post '/api/v1/reset-password', params: reset_params, as: :json

        reset_key = UserPasswordResetKey.find_by(id: user.id)
        expect(reset_key).to be_nil
      end
    end

    context 'with invalid reset token' do
      it 'returns error for wrong token' do
        reset_params = {
          email: user.email,
          reset_code: '999999',
          new_password: 'NewPassword456!'
        }

        post '/api/v1/reset-password', params: reset_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to include('Invalid or expired reset token')

        # Verify password was NOT updated
        user.reload
        expect(user.valid_password?('OldPassword123!')).to be true
      end
    end

    context 'with expired reset token' do
      it 'returns error for expired token' do
        # Update deadline to past
        UserPasswordResetKey.find_by(id: user.id).update!(deadline: 1.hour.ago)

        reset_params = {
          email: user.email,
          reset_code: reset_code,
          new_password: 'NewPassword456!'
        }

        post '/api/v1/reset-password', params: reset_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to include('Invalid or expired reset token')
      end
    end

    context 'with missing parameters' do
      it 'returns error for missing email' do
        reset_params = {
          reset_code: reset_code,
          new_password: 'NewPassword456!'
        }

        post '/api/v1/reset-password', params: reset_params, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['message']).to include('Email, reset code, and new password are required')
      end

      it 'returns error for missing code' do
        reset_params = {
          email: user.email,
          new_password: 'NewPassword456!'
        }

        post '/api/v1/reset-password', params: reset_params, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['message']).to include('Email, reset code, and new password are required')
      end

      it 'returns error for missing password' do
        reset_params = {
          email: user.email,
          reset_code: reset_code
        }

        post '/api/v1/reset-password', params: reset_params, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['message']).to include('Email, reset code, and new password are required')
      end
    end

    context 'with non-existent user' do
      it 'returns error for unknown email' do
        reset_params = {
          email: 'unknown@example.com',
          reset_code: reset_code,
          new_password: 'NewPassword456!'
        }

        post '/api/v1/reset-password', params: reset_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to include('Invalid or expired reset token')
      end
    end

    context 'with server errors' do
      it 'handles database errors gracefully' do
        reset_params = {
          email: user.email,
          reset_code: reset_code,
          new_password: 'NewPassword456!'
        }

        # Mock a database error
        allow(UserPasswordResetKey).to receive(:find_for_reset).and_raise(StandardError.new('Database error'))

        post '/api/v1/reset-password', params: reset_params, as: :json

        expect(response).to have_http_status(:internal_server_error)
        expect(response.parsed_body['message']).to include('Password reset failed')
      end
    end
  end
end
