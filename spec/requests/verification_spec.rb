# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Email Verification API' do
  let!(:user) do
    User.create!(
      email: 'test@example.com',
      password_hash: 'hashed_password',
      first_name: 'John',
      last_name: 'Doe',
      status: :unverified,
      isVerified: false
    )
  end
  let(:verification_code) { '123456' }

  before do
    # Create verification record
    UserVerificationKey.create!(
      id: user.id,
      key: verification_code,
      requested_at: Time.current,
      email_last_sent: Time.current
    )
  end

  describe 'POST /api/v1/verify-email' do
    context 'with valid verification code' do
      it 'verifies user email successfully' do
        verification_params = {
          email: user.email,
          code: verification_code
        }

        post '/api/v1/verify-email', params: verification_params, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(
          'success' => true,
          'message' => 'Email verified successfully'
        )

        user.reload
        expect(user.isVerified).to be true
        expect(user.status).to eq('verified')

        # Verification key should be deleted
        verification_record = UserVerificationKey.find_by(id: user.id)
        expect(verification_record).to be_nil
      end
    end

    context 'with invalid verification code' do
      it 'returns error for wrong code' do
        verification_params = {
          email: user.email,
          code: '999999'
        }

        post '/api/v1/verify-email', params: verification_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to include('Invalid or expired verification code')

        user.reload
        expect(user.isVerified).to be false
      end
    end

    context 'with missing parameters' do
      it 'returns error for missing email' do
        verification_params = { code: verification_code }

        post '/api/v1/verify-email', params: verification_params, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['message']).to include('Email and verification code are required')
      end

      it 'returns error for missing code' do
        verification_params = { email: user.email }

        post '/api/v1/verify-email', params: verification_params, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['message']).to include('Email and verification code are required')
      end
    end

    context 'with non-existent user' do
      it 'returns error for unknown email' do
        verification_params = {
          email: 'unknown@example.com',
          code: verification_code
        }

        post '/api/v1/verify-email', params: verification_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to include('User not found')
      end
    end

    context 'with server errors' do
      it 'handles database errors gracefully' do
        verification_params = {
          email: user.email,
          code: verification_code
        }

        # Mock a database error
        allow(UserVerificationKey).to receive(:find_for_verification).and_raise(StandardError.new('Database error'))

        post '/api/v1/verify-email', params: verification_params, as: :json

        expect(response).to have_http_status(:internal_server_error)
        expect(response.parsed_body['message']).to include('Verification failed')
      end
    end
  end

  describe 'POST /api/v1/resend-verification' do
    context 'with valid unverified user' do
      it 'sends new verification code' do
        expect do
          post '/api/v1/resend-verification', params: { email: user.email }, as: :json
        end.to have_enqueued_mail(UserMailer, :email_verification)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(
          'success' => true,
          'message' => 'Verification email sent successfully'
        )

        # Should contain new verification code in development
        expect(response.parsed_body['data']['verification_code']).to match(/\A\d{6}\z/)
      end

      it 'updates verification code in database' do
        old_code = verification_code

        post '/api/v1/resend-verification', params: { email: user.email }, as: :json

        new_verification_record = UserVerificationKey.find_by(id: user.id)

        expect(new_verification_record.key).not_to eq(old_code)
        expect(new_verification_record.key).to match(/\A\d{6}\z/)
      end
    end

    context 'with already verified user' do
      before do
        user.update!(status: :verified, isVerified: true)
      end

      it 'returns error for verified user' do
        post '/api/v1/resend-verification', params: { email: user.email }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to include('Email is already verified')
      end
    end

    context 'with missing email' do
      it 'returns error for missing email' do
        post '/api/v1/resend-verification', params: {}, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['message']).to include('Email is required')
      end
    end

    context 'with non-existent user' do
      it 'returns error for unknown email' do
        post '/api/v1/resend-verification', params: { email: 'unknown@example.com' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to include('User not found')
      end
    end
  end
end
