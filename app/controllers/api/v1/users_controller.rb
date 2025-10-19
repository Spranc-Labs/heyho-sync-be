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
        result = ::Users::ProfileService.update_profile(@user, user_params)

        if result.success?
          render_json_response(
            success: true,
            message: result.message || 'User updated successfully',
            data: {
              user: UserSerializer.new(result.data).as_json
            }
          )
        else
          render_error_response(
            message: result.message || 'User could not be updated',
            errors: result.error_messages,
            status: :unprocessable_entity
          )
        end
      end

      # PATCH /api/v1/users/me/password
      def update_password
        result = ::Users::ProfileService.update_password(
          @user,
          current_password: password_params[:current_password],
          new_password: password_params[:password]
        )

        if result.success?
          render_json_response(
            success: true,
            message: result.message || 'Password updated successfully',
            data: {
              user: UserSerializer.new(result.data).as_json
            }
          )
        else
          render_error_response(
            message: result.message || 'Password could not be updated',
            errors: result.error_messages,
            status: :unprocessable_entity
          )
        end
      end

      private

      def set_current_user
        @user = current_user
      end

      def user_params
        params.permit(:email, :first_name, :last_name)
      end

      def password_params
        params.require(:user).permit(:current_password, :password)
      end
    end
  end
end
