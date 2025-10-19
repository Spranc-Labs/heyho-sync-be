# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentication API' do
  let(:user_params) do
    {
      email: 'test@example.com',
      password: 'password123',
      first_name: 'John',
      last_name: 'Doe'
    }
  end

  describe 'POST /api/v1/auth/create-account' do
    context 'with valid parameters' do
      it 'creates a new user account' do
        expect do
          post '/api/v1/auth/create-account', params: user_params, as: :json
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(
          'success' => true,
          'message' => 'Account created successfully. Please verify your email.',
          'verification_code' => a_string_matching(/\A\d{6}\z/)
        )

        user_data = response.parsed_body['user']
        expect(user_data).to include(
          'email' => 'test@example.com',
          'first_name' => 'John',
          'last_name' => 'Doe',
          'isVerified' => false
        )
      end
    end

    context 'with missing required fields' do
      it 'returns error for missing first_name' do
        invalid_params = user_params.except(:first_name)

        post '/api/v1/auth/create-account', params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('There was an error creating your account')
      end

      it 'returns error for missing email' do
        invalid_params = user_params.except(:email)

        post '/api/v1/auth/create-account', params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with duplicate email' do
      before { User.create!(user_params.merge(status: :unverified)) }

      it 'returns error for existing email' do
        post '/api/v1/auth/create-account', params: user_params, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/auth/login' do
    let!(:user) do
      User.create!(user_params.merge(status: :verified, isVerified: true))
    end

    context 'with valid credentials' do
      it 'returns JWT tokens' do
        login_params = { email: user.email, password: 'password123' }

        post '/api/v1/auth/login', params: login_params, as: :json

        expect(response).to have_http_status(:ok)

        data = response.parsed_body['data']
        expect(data).to include(
          'AccessToken' => a_string_matching(/\A[\w\-\.]+\z/),
          'RefreshToken' => a_string_matching(/\A[\w\-\.]+\z/),
          'IdToken' => a_string_matching(/\A[\w\-\.]+\z/),
          'ExpiresIn' => 3600,
          'TokenType' => 'Bearer'
        )
      end
    end

    context 'with invalid credentials' do
      it 'returns error for wrong password' do
        login_params = { email: user.email, password: 'wrongpassword' }

        post '/api/v1/auth/login', params: login_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns error for non-existent email' do
        login_params = { email: 'nonexistent@example.com', password: 'password123' }

        post '/api/v1/auth/login', params: login_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with unverified account' do
      let!(:unverified_user) do
        User.create!(user_params.merge(email: 'unverified@example.com', status: :unverified, isVerified: false))
      end

      it 'returns error for unverified account' do
        login_params = { email: unverified_user.email, password: 'password123' }

        post '/api/v1/auth/login', params: login_params, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/auth/logout' do
    let!(:user) { User.create!(user_params.merge(status: :verified, isVerified: true)) }
    let(:access_token) { generate_jwt_token(user) }

    it 'successfully logs out user' do
      post '/api/v1/auth/logout', headers: auth_headers(access_token), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'statusCode' => 200,
        'message' => 'User logged out successfully'
      )
    end

    it 'revokes JWT token making it invalid for future requests' do
      # First verify token works
      get '/api/v1/users/me', headers: auth_headers(access_token), as: :json
      expect(response).to have_http_status(:ok)

      # Logout (should revoke token)
      post '/api/v1/auth/logout', headers: auth_headers(access_token), as: :json
      expect(response).to have_http_status(:ok)

      # Try to use same token again - should fail
      get '/api/v1/users/me', headers: auth_headers(access_token), as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  private

  def generate_jwt_token(user)
    payload = {
      sub: user.id,
      jti: SecureRandom.uuid,
      iss: 'heyho-sync-api',
      aud: 'heyho-sync-app',
      iat: Time.current.to_i,
      exp: Time.current.to_i + 3600,
      scope: 'user'
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers(token)
    { 'Authorization' => "Bearer #{token}" }
  end
end
