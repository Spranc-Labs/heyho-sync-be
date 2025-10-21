# frozen_string_literal: true

class CreateResearchSessions < ActiveRecord::Migration[7.0]
  def change
    create_table :research_sessions, id: :bigserial do |t|
      # Associations
      t.references :user, null: false, foreign_key: true, index: true

      # Session metadata
      t.string :session_name, null: false
      t.timestamp :session_start, null: false
      t.timestamp :session_end, null: false

      # Session stats
      t.integer :tab_count, null: false
      t.string :primary_domain
      t.string :domains, array: true, default: []
      t.string :topics, array: true, default: [] # Extracted keywords

      # Aggregated engagement
      t.integer :total_duration_seconds
      t.float :avg_engagement_rate

      # User actions
      t.string :status, limit: 50, default: 'detected', null: false # 'detected', 'saved', 'restored', 'dismissed'
      t.timestamp :saved_at
      t.timestamp :last_restored_at
      t.integer :restore_count, default: 0

      t.timestamps
    end

    # Indexes
    add_index :research_sessions, %i[user_id status], name: 'idx_research_sessions_user_status'
    add_index :research_sessions, :session_start, name: 'idx_research_sessions_start'
    add_index :research_sessions, :primary_domain, name: 'idx_research_sessions_domain'
  end
end
