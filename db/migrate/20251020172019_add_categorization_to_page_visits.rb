# frozen_string_literal: true

class AddCategorizationToPageVisits < ActiveRecord::Migration[7.0]
  def change
    add_column :page_visits, :category, :string
    add_column :page_visits, :category_confidence, :float
    add_column :page_visits, :category_method, :string

    # Add indexes for efficient category filtering
    add_index :page_visits, [:user_id, :category]
    add_index :page_visits, :category
  end
end
