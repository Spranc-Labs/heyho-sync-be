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

ActiveRecord::Schema[7.0].define(version: 2025_10_20_172053) do
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
    t.datetime "closed_at", null: false
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
  add_foreign_key "sync_logs", "users"
  add_foreign_key "tab_aggregates", "page_visits"
  add_foreign_key "user_login_change_keys", "users", column: "id"
  add_foreign_key "user_password_reset_keys", "users", column: "id"
  add_foreign_key "user_remember_keys", "users", column: "id"
  add_foreign_key "user_verification_keys", "users", column: "id"
end
