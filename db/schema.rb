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

ActiveRecord::Schema[8.1].define(version: 2026_06_21_110047) do
  create_table "access_logs", force: :cascade do |t|
    t.integer "bytes_read"
    t.string "client_ip"
    t.datetime "created_at", null: false
    t.float "duration"
    t.string "host"
    t.string "method"
    t.string "proto"
    t.text "referer"
    t.string "remote_ip"
    t.string "request_id"
    t.string "server_name"
    t.integer "size"
    t.integer "status"
    t.datetime "timestamp"
    t.string "tls_proto"
    t.integer "tls_version"
    t.datetime "updated_at", null: false
    t.text "uri"
    t.text "user_agent"
    t.index ["host"], name: "index_access_logs_on_host"
    t.index ["method"], name: "index_access_logs_on_method"
    t.index ["remote_ip"], name: "index_access_logs_on_remote_ip"
    t.index ["status"], name: "index_access_logs_on_status"
    t.index ["timestamp"], name: "index_access_logs_on_timestamp"
  end

  create_table "error_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "duration"
    t.string "err_id"
    t.string "err_trace"
    t.string "host"
    t.string "level"
    t.text "message"
    t.string "method"
    t.string "remote_ip"
    t.string "source"
    t.integer "status"
    t.datetime "timestamp"
    t.datetime "updated_at", null: false
    t.text "uri"
    t.index ["host"], name: "index_error_logs_on_host"
    t.index ["remote_ip"], name: "index_error_logs_on_remote_ip"
    t.index ["status"], name: "index_error_logs_on_status"
    t.index ["timestamp"], name: "index_error_logs_on_timestamp"
  end

  create_table "import_locks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "locked_at"
    t.string "state", default: "idle", null: false
    t.datetime "updated_at", null: false
  end

  create_table "imported_files", force: :cascade do |t|
    t.integer "byte_offset", default: 0, null: false
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.datetime "last_imported_at"
    t.datetime "updated_at", null: false
    t.index ["filename"], name: "index_imported_files_on_filename", unique: true
  end
end
