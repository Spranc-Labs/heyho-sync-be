# frozen_string_literal: true

module Users
  class ProfileService < ::BaseService
    def self.call(action, user, params)
      new(user, params).send(action)
    end

    def self.update_profile(user, params)
      new(user, params).update_profile
    end

    def self.update_password(user, current_password:, new_password:)
      new(user, current_password:, new_password:).update_password
    end

    def initialize(user, params = {})
      super() # BaseService has no state to initialize
      @user = user
      @params = params
    end

    def update_profile
      return failure_result(message: 'Invalid parameters') unless profile_params_valid?

      if @user.update(@params)
        success_result(data: @user, message: 'Profile updated successfully')
      else
        failure_result(errors: @user.errors.full_messages)
      end
    end

    def update_password
      return failure_result(message: 'Current password is incorrect') unless password_valid?
      return failure_result(message: 'New password is required') if new_password.blank?

      @user.password_hash = hash_password(new_password)

      if @user.save
        success_result(data: @user, message: 'Password updated successfully')
      else
        failure_result(errors: @user.errors.full_messages)
      end
    end

    private

    attr_reader :user, :params

    def profile_params_valid?
      @params.is_a?(Hash) || @params.is_a?(ActionController::Parameters)
    end

    def password_valid?
      @user.valid_password?(@params[:current_password])
    end

    def new_password
      @params[:new_password]
    end

    def hash_password(password)
      BCrypt::Password.create(password)
    end
  end
end
