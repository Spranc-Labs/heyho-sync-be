# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users API' do
  let!(:user) do
    User.create!(
      email: 'test@example.com',
      password_hash: BCrypt::Password.create('password123'),
      first_name: 'John',
      last_name: 'Doe',
      status: :verified,
      isVerified: true
    )
  end
  let(:access_token) { generate_jwt_token(user) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{access_token}" } }

  describe 'GET /api/v1/users/me' do
    context 'with valid authentication' do
      it 'returns current user profile' do
        get '/api/v1/users/me', headers: auth_headers

        expect(response).to have_http_status(:ok)

        user_data = response.parsed_body['data']['user']
        expect(user_data).to include(
          'id' => user.id,
          'email' => 'test@example.com',
          'first_name' => 'John',
          'last_name' => 'Doe',
          'isVerified' => true
        )
        expect(user_data).to have_key('created_at')
        expect(user_data).to have_key('updated_at')
      end
    end

    context 'without authentication' do
      it 'returns unauthorized error' do
        get '/api/v1/users/me'

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      it 'returns unauthorized error' do
        get '/api/v1/users/me', headers: { 'Authorization' => 'Bearer invalid_token' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/users/me' do
    context 'with valid authentication and data' do
      it 'updates user profile successfully' do
        update_params = {
          first_name: 'Jane',
          last_name: 'Smith'
        }

        patch '/api/v1/users/me', params: update_params, headers: auth_headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(
          'success' => true,
          'message' => 'Profile updated successfully'
        )

        user_data = response.parsed_body['data']['user']
        expect(user_data).to include(
          'first_name' => 'Jane',
          'last_name' => 'Smith',
          'email' => 'test@example.com' # Should remain unchanged
        )

        user.reload
        expect(user.first_name).to eq('Jane')
        expect(user.last_name).to eq('Smith')
      end

      it 'updates email successfully' do
        update_params = { email: 'newemail@example.com' }

        patch '/api/v1/users/me', params: update_params, headers: auth_headers, as: :json

        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.email).to eq('newemail@example.com')
      end

      it 'handles partial updates' do
        update_params = { first_name: 'Updated' }

        patch '/api/v1/users/me', params: update_params, headers: auth_headers, as: :json

        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.first_name).to eq('Updated')
        expect(user.last_name).to eq('Doe') # Should remain unchanged
      end
    end

    context 'with invalid data' do
      it 'handles empty parameters gracefully' do
        patch '/api/v1/users/me', params: {}, headers: auth_headers, as: :json

        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.first_name).to eq('John') # Should remain unchanged
      end

      it 'rejects invalid email format' do
        update_params = { email: 'invalid_email' }

        patch '/api/v1/users/me', params: update_params, headers: auth_headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['errors']).to be_present
      end
    end

    context 'without authentication' do
      it 'returns unauthorized error' do
        patch '/api/v1/users/me', params: { first_name: 'Test' }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/users/me/password' do
    context 'with valid current password' do
      it 'updates password successfully' do
        password_params = {
          current_password: 'password123',
          password: 'newpassword123'
        }

        patch '/api/v1/users/me/password',
              params: { user: password_params },
              headers: auth_headers,
              as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(
          'success' => true,
          'message' => 'Password updated successfully'
        )
      end
    end

    context 'with invalid current password' do
      it 'returns error' do
        password_params = {
          current_password: 'wrongpassword',
          password: 'newpassword123'
        }

        patch '/api/v1/users/me/password',
              params: { user: password_params },
              headers: auth_headers,
              as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['message']).to eq('Current password is incorrect')
      end
    end

    context 'with missing required fields' do
      it 'returns error for missing current_password' do
        password_params = { password: 'newpassword123' }

        patch '/api/v1/users/me/password',
              params: { user: password_params },
              headers: auth_headers,
              as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized error' do
        password_params = {
          current_password: 'password123',
          password: 'newpassword123'
        }

        patch '/api/v1/users/me/password', params: { user: password_params }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  private

  def generate_jwt_token(user)
    payload = {
      sub: user.id,
      iss: 'heyho-sync-api',
      aud: 'heyho-sync-app',
      iat: Time.current.to_i,
      exp: Time.current.to_i + 3600,
      scope: 'user'
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end
end
