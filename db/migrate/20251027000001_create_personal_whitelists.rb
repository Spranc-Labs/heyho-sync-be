# frozen_string_literal: true

class CreatePersonalWhitelists < ActiveRecord::Migration[7.0]
  def change
    create_table :personal_whitelists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :domain, null: false
      t.string :whitelist_reason  # 'work_tool', 'music_routine', 'reference', 'manual'
      t.integer :routine_score
      t.datetime :detected_at
      t.datetime :last_verified_at
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end

    add_index :personal_whitelists, [:user_id, :domain], unique: true, where: 'is_active = true'
    add_index :personal_whitelists, [:user_id, :is_active]
    add_index :personal_whitelists, :whitelist_reason
  end
end
