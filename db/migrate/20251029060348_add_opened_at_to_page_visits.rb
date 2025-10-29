# frozen_string_literal: true

class AddOpenedAtToPageVisits < ActiveRecord::Migration[7.0]
  def up
    add_column :page_visits, :opened_at, :datetime
    add_index :page_visits, :opened_at

    # Backfill opened_at for existing records
    # For existing data, we don't have the actual tab open time, so use visited_at as best approximation
    # Future records will have accurate opened_at set by browser extension
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE page_visits
          SET opened_at = visited_at
          WHERE opened_at IS NULL
        SQL
      end
    end
  end

  def down
    remove_index :page_visits, :opened_at
    remove_column :page_visits, :opened_at
  end
end
