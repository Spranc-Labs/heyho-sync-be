# frozen_string_literal: true

class UserSerializer
  include ActiveModel::Serialization

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def as_json(_options = {})
    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      isVerified: user.isVerified,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end
end
