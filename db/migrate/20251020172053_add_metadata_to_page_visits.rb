# frozen_string_literal: true

class AddMetadataToPageVisits < ActiveRecord::Migration[7.0]
  def change
    add_column :page_visits, :metadata, :jsonb, default: {}

    # Add GIN index for efficient JSONB queries
    add_index :page_visits, :metadata, using: :gin
  end
end
