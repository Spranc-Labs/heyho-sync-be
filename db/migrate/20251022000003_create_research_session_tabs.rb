# frozen_string_literal: true

class CreateResearchSessionTabs < ActiveRecord::Migration[7.0]
  def change
    create_table :research_session_tabs, id: :bigserial do |t|
      # Associations
      t.references :research_session, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.string :page_visit_id, null: false

      # Tab metadata
      t.integer :tab_order # Order in which tabs were opened
      t.string :url, null: false
      t.string :title
      t.string :domain

      t.timestamps
    end

    # Foreign key to page_visits
    add_foreign_key :research_session_tabs, :page_visits, column: :page_visit_id, primary_key: :id, on_delete: :cascade

    # Indexes
    add_index :research_session_tabs, :page_visit_id, name: 'idx_session_tabs_page_visit'
    add_index :research_session_tabs, %i[research_session_id tab_order], name: 'idx_session_tabs_order'
  end
end
