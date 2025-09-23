# frozen_string_literal: true

module Api
  module V1
    class UsersController < AuthenticatedController
      before_action :set_current_user

      # GET /api/v1/users/me
      def me
        render_json_response(
          success: true,
          data: {
            user: UserSerializer.new(@user).as_json
          }
        )
      end

      # PATCH /api/v1/users/me
      def update
        if @user.update(user_params)
          render_json_response(
            success: true,
            message: 'User updated successfully',
            data: {
              user: UserSerializer.new(@user).as_json
            }
          )
        else
          render_error_response(
            message: 'User could not be updated',
            errors: @user.errors.full_messages,
            status: :unprocessable_entity
          )
        end
      end

      # PATCH /api/v1/users/me/password
      def update_password
        unless @user.valid_password?(password_params[:current_password])
          render_error_response(
            message: 'Password could not be updated',
            errors: ['Current password is incorrect'],
            status: :unprocessable_entity
          )
          return
        end

        # Set password_confirmation to match password
        @user.password = password_params[:password]
        @user.password_confirmation = password_params[:password]

        if @user.save
          render_json_response(
            success: true,
            message: 'Password updated successfully',
            data: {
              user: UserSerializer.new(@user).as_json
            }
          )
        else
          render_error_response(
            message: 'Password could not be updated',
            errors: @user.errors.full_messages,
            status: :unprocessable_entity
          )
        end
      end

      private

      def set_current_user
        @user = current_user
      end

      def user_params
        params.permit(:email, :first_name, :last_name, :isVerified)
      end

      def password_params
        params.require(:user).permit(:current_password, :password)
      end
    end
  end
end
