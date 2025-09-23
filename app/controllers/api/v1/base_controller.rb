# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      private

      def render_json_response(success:, data: nil, message: nil, status: :ok)
        response = { success: }
        response[:data] = data if data
        response[:message] = message if message
        render json: response, status:
      end

      def render_error_response(message:, status: :unprocessable_entity, errors: nil)
        response = { success: false, message: }
        response[:errors] = errors if errors
        render json: response, status:
      end
    end
  end
end
