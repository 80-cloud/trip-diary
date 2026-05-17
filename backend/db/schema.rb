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

ActiveRecord::Schema[8.1].define(version: 2026_05_17_040000) do
  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "comments", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "body", limit: 140, null: false
    t.datetime "created_at", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["trip_id", "created_at"], name: "index_comments_on_trip_id_and_created_at"
    t.index ["trip_id"], name: "index_comments_on_trip_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "day_entries", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "day_number", default: 1, null: false
    t.date "happened_on"
    t.integer "position", default: 0, null: false
    t.string "title", limit: 80, null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id", "position"], name: "index_day_entries_on_trip_id_and_position"
    t.index ["trip_id"], name: "index_day_entries_on_trip_id"
  end

  create_table "favorites", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["trip_id"], name: "index_favorites_on_trip_id"
    t.index ["user_id", "created_at"], name: "index_favorites_on_user_id_and_created_at"
    t.index ["user_id", "trip_id"], name: "index_favorites_on_user_id_and_trip_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "follows", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "followed_id", null: false
    t.bigint "follower_id", null: false
    t.datetime "updated_at", null: false
    t.index ["followed_id"], name: "index_follows_on_followed_id"
    t.index ["follower_id", "followed_id"], name: "index_follows_on_follower_id_and_followed_id", unique: true
    t.index ["follower_id"], name: "index_follows_on_follower_id"
  end

  create_table "likes", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["trip_id", "user_id"], name: "index_likes_on_trip_id_and_user_id", unique: true
    t.index ["trip_id"], name: "index_likes_on_trip_id"
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "memos", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["trip_id"], name: "index_memos_on_trip_id"
    t.index ["user_id", "trip_id"], name: "index_memos_on_user_id_and_trip_id", unique: true
    t.index ["user_id"], name: "index_memos_on_user_id"
  end

  create_table "tags", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", limit: 32, null: false
    t.integer "trips_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["trips_count"], name: "index_tags_on_trips_count"
  end

  create_table "trip_tags", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "tag_id", null: false
    t.bigint "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_trip_tags_on_tag_id"
    t.index ["trip_id", "tag_id"], name: "index_trip_tags_on_trip_id_and_tag_id", unique: true
    t.index ["trip_id"], name: "index_trip_tags_on_trip_id"
  end

  create_table "trips", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.text "body"
    t.string "category", limit: 32, null: false
    t.integer "comments_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "destination", limit: 80, null: false
    t.date "ended_on", null: false
    t.integer "likes_count", default: 0, null: false
    t.date "started_on", null: false
    t.string "status", limit: 16, null: false
    t.string "title", limit: 80, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "visibility", limit: 16, default: "public", null: false
    t.index ["category"], name: "index_trips_on_category"
    t.index ["created_at"], name: "index_trips_on_created_at"
    t.index ["destination"], name: "index_trips_on_destination"
    t.index ["status"], name: "index_trips_on_status"
    t.index ["user_id"], name: "index_trips_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "display_name", limit: 30, null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "comments", "trips", on_delete: :cascade
  add_foreign_key "comments", "users"
  add_foreign_key "day_entries", "trips", on_delete: :cascade
  add_foreign_key "favorites", "trips"
  add_foreign_key "favorites", "users"
  add_foreign_key "follows", "users", column: "followed_id"
  add_foreign_key "follows", "users", column: "follower_id"
  add_foreign_key "likes", "trips", on_delete: :cascade
  add_foreign_key "likes", "users"
  add_foreign_key "memos", "trips"
  add_foreign_key "memos", "users"
  add_foreign_key "trip_tags", "tags"
  add_foreign_key "trip_tags", "trips"
  add_foreign_key "trips", "users"
end
