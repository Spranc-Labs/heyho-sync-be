class ChangePageVisitsIdToString < ActiveRecord::Migration[7.0]
  def up
    # Drop foreign keys first
    remove_foreign_key :page_visits, :page_visits, column: :source_page_visit_id if foreign_key_exists?(:page_visits, column: :source_page_visit_id)
    remove_foreign_key :tab_aggregates, :page_visits if foreign_key_exists?(:tab_aggregates, :page_visits)

    # Change page_visits primary key and related columns
    change_column :page_visits, :id, :string, null: false, default: nil
    change_column :page_visits, :source_page_visit_id, :string, null: true

    # Change tab_aggregates primary key and foreign key
    change_column :tab_aggregates, :id, :string, null: false, default: nil
    change_column :tab_aggregates, :page_visit_id, :string, null: false

    # Re-add foreign keys
    add_foreign_key :page_visits, :page_visits, column: :source_page_visit_id
    add_foreign_key :tab_aggregates, :page_visits
  end

  def down
    # Drop foreign keys
    remove_foreign_key :page_visits, :page_visits, column: :source_page_visit_id
    remove_foreign_key :tab_aggregates, :page_visits

    # Revert to UUID
    change_column :page_visits, :id, :uuid, using: 'id::uuid', null: false
    change_column :page_visits, :source_page_visit_id, :uuid, using: 'source_page_visit_id::uuid', null: true

    change_column :tab_aggregates, :id, :uuid, using: 'id::uuid', null: false
    change_column :tab_aggregates, :page_visit_id, :uuid, using: 'page_visit_id::uuid', null: false

    # Re-add foreign keys
    add_foreign_key :page_visits, :page_visits, column: :source_page_visit_id
    add_foreign_key :tab_aggregates, :page_visits
  end
end
