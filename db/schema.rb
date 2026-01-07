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

ActiveRecord::Schema[7.1].define(version: 2026_01_04_215904) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "employees", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "role", default: "employee", null: false
    t.string "department"
    t.string "contract_type", null: false
    t.date "start_date", null: false
    t.bigint "manager_id"
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "phone"
    t.text "address"
    t.string "job_title"
    t.date "end_date"
    t.jsonb "contract_overrides", default: {}, null: false
    t.index ["department"], name: "index_employees_on_department"
    t.index ["email"], name: "index_employees_on_email", unique: true
    t.index ["manager_id"], name: "index_employees_on_manager_id"
    t.index ["organization_id", "email"], name: "index_employees_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_employees_on_organization_id"
    t.index ["reset_password_token"], name: "index_employees_on_reset_password_token", unique: true
    t.index ["role"], name: "index_employees_on_role"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti"
    t.datetime "exp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "leave_balances", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "leave_type", null: false
    t.decimal "balance", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "accrued_this_year", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "used_this_year", precision: 10, scale: 2, default: "0.0", null: false
    t.date "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["employee_id", "leave_type"], name: "index_leave_balances_on_employee_id_and_leave_type", unique: true
    t.index ["employee_id"], name: "index_leave_balances_on_employee_id"
    t.index ["expires_at"], name: "index_leave_balances_on_expires_at"
    t.index ["leave_type"], name: "index_leave_balances_on_leave_type"
    t.index ["organization_id", "created_at"], name: "index_leave_balances_on_organization_id_and_created_at"
  end

  create_table "leave_requests", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "leave_type", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.decimal "days_count", precision: 10, scale: 2, null: false
    t.string "status", default: "pending", null: false
    t.text "reason"
    t.bigint "approved_by_id"
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "rejection_reason"
    t.string "start_half_day"
    t.string "end_half_day"
    t.bigint "organization_id", null: false
    t.index ["approved_by_id"], name: "index_leave_requests_on_approved_by_id"
    t.index ["employee_id", "status"], name: "index_leave_requests_on_employee_id_and_status"
    t.index ["employee_id"], name: "index_leave_requests_on_employee_id"
    t.index ["end_date"], name: "index_leave_requests_on_end_date"
    t.index ["organization_id", "created_at"], name: "index_leave_requests_on_organization_id_and_created_at"
    t.index ["start_date"], name: "index_leave_requests_on_start_date"
    t.index ["status"], name: "index_leave_requests_on_status"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "title", null: false
    t.text "message"
    t.string "notification_type", null: false
    t.datetime "read_at"
    t.string "related_type"
    t.integer "related_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["employee_id", "created_at"], name: "index_notifications_on_employee_id_and_created_at"
    t.index ["employee_id", "read_at"], name: "index_notifications_on_employee_id_and_read_at"
    t.index ["employee_id"], name: "index_notifications_on_employee_id"
    t.index ["organization_id", "created_at"], name: "index_notifications_on_organization_id_and_created_at"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "siret"
    t.text "address"
    t.index ["name"], name: "index_organizations_on_name"
  end

  create_table "time_entries", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.datetime "clock_in", null: false
    t.datetime "clock_out"
    t.integer "duration_minutes", default: 0, null: false
    t.jsonb "location", default: {}
    t.boolean "manual_override", default: false, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "validated_at"
    t.bigint "validated_by_id"
    t.datetime "rejected_at"
    t.bigint "rejected_by_id"
    t.text "rejection_reason"
    t.bigint "organization_id", null: false
    t.index ["clock_in"], name: "index_time_entries_on_clock_in"
    t.index ["clock_out"], name: "index_time_entries_on_clock_out"
    t.index ["employee_id", "clock_in"], name: "index_time_entries_on_employee_id_and_clock_in"
    t.index ["employee_id", "clock_out"], name: "index_time_entries_on_employee_id_and_clock_out"
    t.index ["employee_id"], name: "index_time_entries_on_employee_id"
    t.index ["organization_id", "created_at"], name: "index_time_entries_on_organization_id_and_created_at"
    t.index ["rejected_at"], name: "index_time_entries_on_rejected_at"
    t.index ["rejected_by_id"], name: "index_time_entries_on_rejected_by_id"
    t.index ["validated_at"], name: "index_time_entries_on_validated_at"
    t.index ["validated_by_id"], name: "index_time_entries_on_validated_by_id"
  end

  create_table "weekly_schedule_plans", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.date "week_start_date", null: false
    t.jsonb "schedule_pattern", default: "{}", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["employee_id", "week_start_date"], name: "index_weekly_schedule_plans_on_employee_id_and_week_start_date", unique: true
    t.index ["employee_id"], name: "index_weekly_schedule_plans_on_employee_id"
    t.index ["organization_id", "created_at"], name: "index_weekly_schedule_plans_on_organization_id_and_created_at"
  end

  create_table "work_schedules", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "name", null: false
    t.decimal "weekly_hours", precision: 10, scale: 2, default: "35.0", null: false
    t.jsonb "schedule_pattern", default: {}, null: false
    t.decimal "rtt_accrual_rate", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["employee_id"], name: "index_work_schedules_on_employee_id", unique: true
    t.index ["organization_id", "created_at"], name: "index_work_schedules_on_organization_id_and_created_at"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "employees", "employees", column: "manager_id"
  add_foreign_key "employees", "organizations"
  add_foreign_key "leave_balances", "employees"
  add_foreign_key "leave_balances", "organizations"
  add_foreign_key "leave_requests", "employees"
  add_foreign_key "leave_requests", "employees", column: "approved_by_id"
  add_foreign_key "leave_requests", "organizations"
  add_foreign_key "notifications", "employees"
  add_foreign_key "notifications", "organizations"
  add_foreign_key "time_entries", "employees"
  add_foreign_key "time_entries", "employees", column: "rejected_by_id"
  add_foreign_key "time_entries", "employees", column: "validated_by_id"
  add_foreign_key "time_entries", "organizations"
  add_foreign_key "weekly_schedule_plans", "employees"
  add_foreign_key "weekly_schedule_plans", "organizations"
  add_foreign_key "work_schedules", "employees"
  add_foreign_key "work_schedules", "organizations"
end
