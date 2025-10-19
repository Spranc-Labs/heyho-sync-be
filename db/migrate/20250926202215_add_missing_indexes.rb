# frozen_string_literal: true

class AddMissingIndexes < ActiveRecord::Migration[7.0]
  def change
    # Add unique index for jwt_denylists.jti if not exists
    unless index_exists?(:jwt_denylists, :jti)
      add_index :jwt_denylists, :jti, unique: true
    end

    # Add index for jwt_denylists.exp for cleanup queries
    unless index_exists?(:jwt_denylists, :exp)
      add_index :jwt_denylists, :exp
    end

    # Note: refresh_tokens table doesn't exist in current schema
    # Will need to be created if token refresh functionality is needed
  end
end