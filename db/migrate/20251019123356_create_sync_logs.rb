class CreateSyncLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :sync_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :synced_at, null: false
      t.integer :page_visits_synced, default: 0, null: false
      t.integer :tab_aggregates_synced, default: 0, null: false
      t.string :status, null: false, default: 'pending'
      t.jsonb :error_messages, default: []
      t.jsonb :client_info, default: {}

      t.timestamps
    end

    add_index :sync_logs, :status
    add_index :sync_logs, :synced_at
    add_index :sync_logs, [:user_id, :synced_at]
  end
end
