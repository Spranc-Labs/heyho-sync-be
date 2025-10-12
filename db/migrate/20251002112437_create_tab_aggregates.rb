class CreateTabAggregates < ActiveRecord::Migration[7.0]
  def change
    create_table :tab_aggregates, id: :uuid do |t|
      t.uuid :page_visit_id, null: false
      t.integer :total_time_seconds, null: false, default: 0
      t.integer :active_time_seconds, null: false, default: 0
      t.integer :scroll_depth_percent, default: 0
      t.datetime :closed_at, null: false

      t.timestamps
    end

    add_index :tab_aggregates, :page_visit_id
    add_foreign_key :tab_aggregates, :page_visits
  end
end
