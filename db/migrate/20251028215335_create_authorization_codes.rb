# frozen_string_literal: true

# Migration to create authorization_codes table for OAuth2 flow
# Enables Syrupy to request authorization from HeyHo users
class CreateAuthorizationCodes < ActiveRecord::Migration[7.0]
  def change
    create_table :authorization_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code, null: false, index: { unique: true }
      t.string :client_id, null: false
      t.string :redirect_uri, null: false
      t.string :scope, default: 'browsing_data:read'
      t.datetime :expires_at, null: false
      t.boolean :used, default: false, null: false
      t.datetime :used_at

      t.timestamps
    end

    add_index :authorization_codes, :expires_at
    add_index :authorization_codes, [:code, :used], name: 'index_auth_codes_on_code_and_used'
  end
end
