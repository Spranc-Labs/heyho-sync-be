# frozen_string_literal: true

class CreateReadingListItems < ActiveRecord::Migration[7.0]
  def change
    create_table :reading_list_items, id: :bigserial do |t|
      # Associations
      t.references :user, null: false, foreign_key: true, index: true
      t.string :page_visit_id, null: true

      # Core fields
      t.text :url, null: false
      t.string :title
      t.string :domain

      # Metadata
      t.timestamp :added_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.string :added_from, limit: 50 # 'hoarder_detection', 'manual_save', 'serial_opener', 'research_session'
      t.string :status, limit: 50, default: 'unread', null: false # 'unread', 'reading', 'completed', 'dismissed'

      # Optional fields
      t.integer :estimated_read_time # seconds
      t.text :notes
      t.string :tags, array: true, default: []
      t.timestamp :scheduled_for
      t.timestamp :completed_at
      t.timestamp :dismissed_at

      t.timestamps
    end

    # Foreign key to page_visits (if exists)
    add_foreign_key :reading_list_items, :page_visits, column: :page_visit_id, primary_key: :id, on_delete: :nullify

    # Indexes
    add_index :reading_list_items, %i[user_id status], name: 'idx_reading_list_user_status'
    add_index :reading_list_items, :scheduled_for, where: "status = 'unread'", name: 'idx_reading_list_scheduled'
    add_index :reading_list_items, :added_at, name: 'idx_reading_list_added_at'

    # Unique constraint: can't save same URL twice per user
    add_index :reading_list_items, %i[user_id url], unique: true, name: 'idx_reading_list_user_url_unique'
  end
end
