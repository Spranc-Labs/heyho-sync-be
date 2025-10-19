class CreatePageVisits < ActiveRecord::Migration[7.0]
  def change
    create_table :page_visits, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :integer
      t.string :url, null: false
      t.string :title, null: false
      t.datetime :visited_at, null: false
      t.uuid :source_page_visit_id

      t.timestamps
    end

    add_index :page_visits, :visited_at
    add_index :page_visits, :source_page_visit_id
    add_foreign_key :page_visits, :page_visits, column: :source_page_visit_id
  end
end
