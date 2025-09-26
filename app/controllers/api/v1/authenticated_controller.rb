# frozen_string_literal: true

module Api
  module V1
    class AuthenticatedController < BaseController
      include ::Authentication
    end
  end
end
