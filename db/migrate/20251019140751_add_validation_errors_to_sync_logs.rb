class AddValidationErrorsToSyncLogs < ActiveRecord::Migration[7.0]
  def change
    add_column :sync_logs, :validation_errors, :jsonb, default: [], null: false
    add_column :sync_logs, :rejected_records_count, :integer, default: 0, null: false

    add_index :sync_logs, :rejected_records_count
  end
end
