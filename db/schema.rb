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

ActiveRecord::Schema[7.1].define(version: 2025_12_30_221007) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.index ["department"], name: "index_employees_on_department"
    t.index ["email"], name: "index_employees_on_email", unique: true
    t.index ["manager_id"], name: "index_employees_on_manager_id"
    t.index ["organization_id", "email"], name: "index_employees_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_employees_on_organization_id"
    t.index ["reset_password_token"], name: "index_employees_on_reset_password_token", unique: true
    t.index ["role"], name: "index_employees_on_role"
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
    t.index ["employee_id", "leave_type"], name: "index_leave_balances_on_employee_id_and_leave_type", unique: true
    t.index ["employee_id"], name: "index_leave_balances_on_employee_id"
    t.index ["expires_at"], name: "index_leave_balances_on_expires_at"
    t.index ["leave_type"], name: "index_leave_balances_on_leave_type"
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
    t.index ["approved_by_id"], name: "index_leave_requests_on_approved_by_id"
    t.index ["employee_id", "status"], name: "index_leave_requests_on_employee_id_and_status"
    t.index ["employee_id"], name: "index_leave_requests_on_employee_id"
    t.index ["end_date"], name: "index_leave_requests_on_end_date"
    t.index ["start_date"], name: "index_leave_requests_on_start_date"
    t.index ["status"], name: "index_leave_requests_on_status"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_organizations_on_name"
  end

  create_table "time_entries", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.datetime "clock_in", null: false
    t.datetime "clock_out"
    t.integer "duration_minutes"
    t.jsonb "location", default: {}
    t.boolean "manual_override", default: false, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clock_in"], name: "index_time_entries_on_clock_in"
    t.index ["clock_out"], name: "index_time_entries_on_clock_out"
    t.index ["employee_id", "clock_in"], name: "index_time_entries_on_employee_id_and_clock_in"
    t.index ["employee_id", "clock_out"], name: "index_time_entries_on_employee_id_and_clock_out"
    t.index ["employee_id"], name: "index_time_entries_on_employee_id"
  end

  create_table "work_schedules", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "name", null: false
    t.decimal "weekly_hours", precision: 10, scale: 2, default: "35.0", null: false
    t.jsonb "schedule_pattern", default: {}, null: false
    t.decimal "rtt_accrual_rate", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_work_schedules_on_employee_id", unique: true
  end

  add_foreign_key "employees", "employees", column: "manager_id"
  add_foreign_key "employees", "organizations"
  add_foreign_key "leave_balances", "employees"
  add_foreign_key "leave_requests", "employees"
  add_foreign_key "leave_requests", "employees", column: "approved_by_id"
  add_foreign_key "time_entries", "employees"
  add_foreign_key "work_schedules", "employees"
end
