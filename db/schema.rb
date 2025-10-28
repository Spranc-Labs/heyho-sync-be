# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2025_10_28_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti"
    t.datetime "exp"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exp"], name: "index_jwt_denylists_on_exp"
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
    t.index ["user_id"], name: "index_jwt_denylists_on_user_id"
  end

  create_table "page_visits", id: :string, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "url", null: false
    t.string "title", null: false
    t.datetime "visited_at", null: false
    t.string "source_page_visit_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tab_id"
    t.string "domain"
    t.integer "duration_seconds"
    t.integer "active_duration_seconds"
    t.float "engagement_rate"
    t.jsonb "idle_periods"
    t.bigint "last_heartbeat"
    t.string "anonymous_client_id"
    t.string "category"
    t.float "category_confidence"
    t.string "category_method"
    t.jsonb "metadata", default: {}
    t.index ["category"], name: "index_page_visits_on_category"
    t.index ["metadata"], name: "index_page_visits_on_metadata", using: :gin
    t.index ["source_page_visit_id"], name: "index_page_visits_on_source_page_visit_id"
    t.index ["user_id", "category"], name: "index_page_visits_on_user_id_and_category"
    t.index ["user_id", "domain", "visited_at"], name: "index_page_visits_on_user_domain_and_visited_at"
    t.index ["user_id", "domain"], name: "index_page_visits_on_user_and_domain"
    t.index ["user_id", "visited_at"], name: "index_page_visits_on_user_and_visited_at"
    t.index ["user_id"], name: "index_page_visits_on_user_id"
    t.index ["visited_at"], name: "index_page_visits_on_visited_at"
  end

  create_table "personal_whitelists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "domain", null: false
    t.string "whitelist_reason"
    t.integer "routine_score"
    t.datetime "detected_at"
    t.datetime "last_verified_at"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "domain"], name: "index_personal_whitelists_on_user_id_and_domain", unique: true, where: "(is_active = true)"
    t.index ["user_id", "is_active"], name: "index_personal_whitelists_on_user_id_and_is_active"
    t.index ["user_id"], name: "index_personal_whitelists_on_user_id"
    t.index ["whitelist_reason"], name: "index_personal_whitelists_on_whitelist_reason"
  end

  create_table "reading_list_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "page_visit_id"
    t.text "url", null: false
    t.string "title"
    t.string "domain"
    t.datetime "added_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "added_from", limit: 50
    t.string "status", limit: 50, default: "unread", null: false
    t.integer "estimated_read_time"
    t.text "notes"
    t.string "tags", default: [], array: true
    t.datetime "scheduled_for", precision: nil
    t.datetime "completed_at", precision: nil
    t.datetime "dismissed_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["added_at"], name: "idx_reading_list_added_at"
    t.index ["scheduled_for"], name: "idx_reading_list_scheduled", where: "((status)::text = 'unread'::text)"
    t.index ["user_id", "status"], name: "idx_reading_list_user_status"
    t.index ["user_id", "url"], name: "idx_reading_list_user_url_unique", unique: true
    t.index ["user_id"], name: "index_reading_list_items_on_user_id"
  end

  create_table "research_session_tabs", force: :cascade do |t|
    t.bigint "research_session_id", null: false
    t.string "page_visit_id", null: false
    t.integer "tab_order"
    t.string "url", null: false
    t.string "title"
    t.string "domain"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["page_visit_id"], name: "idx_session_tabs_page_visit"
    t.index ["research_session_id", "tab_order"], name: "idx_session_tabs_order"
    t.index ["research_session_id"], name: "index_research_session_tabs_on_research_session_id"
  end

  create_table "research_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "session_name", null: false
    t.datetime "session_start", precision: nil, null: false
    t.datetime "session_end", precision: nil, null: false
    t.integer "tab_count", null: false
    t.string "primary_domain"
    t.string "domains", default: [], array: true
    t.string "topics", default: [], array: true
    t.integer "total_duration_seconds"
    t.float "avg_engagement_rate"
    t.string "status", limit: 50, default: "detected", null: false
    t.datetime "saved_at", precision: nil
    t.datetime "last_restored_at", precision: nil
    t.integer "restore_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["primary_domain"], name: "idx_research_sessions_domain"
    t.index ["session_start"], name: "idx_research_sessions_start"
    t.index ["user_id", "status"], name: "idx_research_sessions_user_status"
    t.index ["user_id"], name: "index_research_sessions_on_user_id"
  end

  create_table "sync_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "synced_at", null: false
    t.integer "page_visits_synced", default: 0, null: false
    t.integer "tab_aggregates_synced", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.jsonb "error_messages", default: []
    t.jsonb "client_info", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "validation_errors", default: [], null: false
    t.integer "rejected_records_count", default: 0, null: false
    t.index ["rejected_records_count"], name: "index_sync_logs_on_rejected_records_count"
    t.index ["status"], name: "index_sync_logs_on_status"
    t.index ["synced_at"], name: "index_sync_logs_on_synced_at"
    t.index ["user_id", "synced_at"], name: "index_sync_logs_on_user_id_and_synced_at"
    t.index ["user_id"], name: "index_sync_logs_on_user_id"
  end

  create_table "tab_aggregates", id: :string, force: :cascade do |t|
    t.string "page_visit_id", null: false
    t.integer "total_time_seconds", default: 0, null: false
    t.integer "active_time_seconds", default: 0, null: false
    t.integer "scroll_depth_percent", default: 0
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "domain_durations"
    t.bigint "page_count"
    t.string "current_url"
    t.string "current_domain"
    t.jsonb "statistics"
    t.index ["page_visit_id"], name: "index_tab_aggregates_on_page_visit_id"
  end

  create_table "user_login_change_keys", force: :cascade do |t|
    t.string "key", null: false
    t.string "login", null: false
    t.datetime "deadline", null: false
  end

  create_table "user_password_reset_keys", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "deadline", null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "user_remember_keys", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "deadline", null: false
  end

  create_table "user_verification_keys", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "requested_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "users", force: :cascade do |t|
    t.citext "email", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "password_hash"
    t.boolean "isVerified", default: false, null: false
    t.integer "status", default: 2, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "jwt_denylists", "users"
  add_foreign_key "page_visits", "page_visits", column: "source_page_visit_id"
  add_foreign_key "page_visits", "users"
  add_foreign_key "personal_whitelists", "users"
  add_foreign_key "reading_list_items", "page_visits", on_delete: :nullify
  add_foreign_key "reading_list_items", "users"
  add_foreign_key "research_session_tabs", "page_visits", on_delete: :cascade
  add_foreign_key "research_session_tabs", "research_sessions", on_delete: :cascade
  add_foreign_key "research_sessions", "users"
  add_foreign_key "sync_logs", "users"
  add_foreign_key "tab_aggregates", "page_visits"
  add_foreign_key "user_login_change_keys", "users", column: "id"
  add_foreign_key "user_password_reset_keys", "users", column: "id"
  add_foreign_key "user_remember_keys", "users", column: "id"
  add_foreign_key "user_verification_keys", "users", column: "id"
end
