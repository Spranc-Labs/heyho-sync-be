# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ActionController::MimeResponds

  protected

  def configure_permitted_parameters
    # This method is for legacy Devise compatibility - not used in Rodauth
  end
end
