# frozen_string_literal: true

class AddCategorizationToPageVisits < ActiveRecord::Migration[7.0]
  def change
    # rubocop:disable Rails/BulkChangeTable
    # Separate add_column calls for clarity in migration history
    add_column :page_visits, :category, :string
    add_column :page_visits, :category_confidence, :float
    add_column :page_visits, :category_method, :string
    # rubocop:enable Rails/BulkChangeTable

    # Add indexes for efficient category filtering
    add_index :page_visits, %i[user_id category]
    add_index :page_visits, :category
  end
end
