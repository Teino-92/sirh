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

ActiveRecord::Schema[7.1].define(version: 2026_02_16_225233) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "action_items", force: :cascade do |t|
    t.bigint "one_on_one_id", null: false
    t.bigint "responsible_id", null: false
    t.bigint "objective_id"
    t.text "description", null: false
    t.date "deadline", null: false
    t.string "status", default: "pending", null: false
    t.string "responsible_type", null: false
    t.date "completed_at"
    t.text "completion_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "organization_id", null: false
    t.index ["deadline"], name: "index_action_items_on_deadline"
    t.index ["objective_id"], name: "index_action_items_on_objective_id"
    t.index ["one_on_one_id"], name: "index_action_items_on_one_on_one_id"
    t.index ["organization_id"], name: "index_action_items_on_organization_id"
    t.index ["responsible_id", "deadline"], name: "idx_action_items_overdue", where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'in_progress'::character varying])::text[]))"
    t.index ["responsible_id", "status", "deadline"], name: "idx_action_items_responsible"
    t.index ["responsible_id"], name: "index_action_items_on_responsible_id"
    t.index ["status"], name: "index_action_items_on_status"
  end

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
    t.index ["manager_id", "organization_id"], name: "idx_employees_manager_org"
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
    t.index ["employee_id", "status"], name: "idx_leave_requests_employee_status"
    t.index ["employee_id", "status"], name: "index_leave_requests_on_employee_id_and_status"
    t.index ["employee_id"], name: "index_leave_requests_on_employee_id"
    t.index ["end_date"], name: "index_leave_requests_on_end_date"
    t.index ["organization_id", "created_at"], name: "index_leave_requests_on_organization_id_and_created_at"
    t.index ["start_date", "end_date"], name: "idx_leave_requests_date_range"
    t.index ["start_date"], name: "index_leave_requests_on_start_date"
    t.index ["status", "created_at"], name: "idx_leave_requests_status_created", where: "((status)::text = 'pending'::text)"
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

  create_table "objectives", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "manager_id", null: false
    t.bigint "created_by_id", null: false
    t.string "owner_type", null: false
    t.bigint "owner_id", null: false
    t.string "title", limit: 255, null: false
    t.text "description"
    t.string "status", default: "draft", null: false
    t.string "priority", default: "medium"
    t.date "deadline", null: false
    t.date "completed_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_objectives_on_created_by_id"
    t.index ["deadline"], name: "index_objectives_on_deadline"
    t.index ["manager_id", "deadline"], name: "idx_objectives_overdue", where: "((status)::text = ANY ((ARRAY['draft'::character varying, 'in_progress'::character varying, 'blocked'::character varying])::text[]))"
    t.index ["manager_id", "status"], name: "idx_objectives_manager_status"
    t.index ["manager_id"], name: "index_objectives_on_manager_id"
    t.index ["organization_id", "status", "deadline"], name: "idx_objectives_org_status_deadline"
    t.index ["organization_id"], name: "index_objectives_on_organization_id"
    t.index ["owner_type", "owner_id", "status"], name: "idx_objectives_owner_status"
    t.index ["owner_type", "owner_id"], name: "index_objectives_on_owner"
    t.index ["status"], name: "index_objectives_on_status"
  end

  create_table "one_on_one_objectives", force: :cascade do |t|
    t.bigint "one_on_one_id", null: false
    t.bigint "objective_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["objective_id"], name: "index_one_on_one_objectives_on_objective_id"
    t.index ["one_on_one_id", "objective_id"], name: "idx_unique_one_on_one_objectives", unique: true
    t.index ["one_on_one_id"], name: "index_one_on_one_objectives_on_one_on_one_id"
  end

  create_table "one_on_ones", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "manager_id", null: false
    t.bigint "employee_id", null: false
    t.datetime "scheduled_at", null: false
    t.datetime "completed_at"
    t.string "status", default: "scheduled", null: false
    t.text "notes"
    t.text "agenda"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "scheduled_at"], name: "idx_one_on_ones_employee"
    t.index ["employee_id"], name: "index_one_on_ones_on_employee_id"
    t.index ["manager_id", "scheduled_at"], name: "idx_one_on_ones_upcoming", where: "((status)::text = 'scheduled'::text)"
    t.index ["manager_id", "status", "scheduled_at"], name: "idx_one_on_ones_manager"
    t.index ["manager_id"], name: "index_one_on_ones_on_manager_id"
    t.index ["organization_id"], name: "index_one_on_ones_on_organization_id"
    t.index ["scheduled_at"], name: "index_one_on_ones_on_scheduled_at"
    t.index ["status"], name: "index_one_on_ones_on_status"
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
    t.index ["employee_id", "clock_in"], name: "idx_time_entries_employee_clock_in"
    t.index ["employee_id", "clock_in"], name: "index_time_entries_on_employee_id_and_clock_in"
    t.index ["employee_id", "clock_out"], name: "index_time_entries_on_employee_id_and_clock_out"
    t.index ["employee_id", "validated_at"], name: "idx_time_entries_employee_validated", where: "(validated_at IS NULL)"
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

  add_foreign_key "action_items", "employees", column: "responsible_id"
  add_foreign_key "action_items", "objectives"
  add_foreign_key "action_items", "one_on_ones"
  add_foreign_key "action_items", "organizations"
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
  add_foreign_key "objectives", "employees", column: "created_by_id"
  add_foreign_key "objectives", "employees", column: "manager_id"
  add_foreign_key "objectives", "organizations"
  add_foreign_key "one_on_one_objectives", "objectives"
  add_foreign_key "one_on_one_objectives", "one_on_ones"
  add_foreign_key "one_on_ones", "employees"
  add_foreign_key "one_on_ones", "employees", column: "manager_id"
  add_foreign_key "one_on_ones", "organizations"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "time_entries", "employees"
  add_foreign_key "time_entries", "employees", column: "rejected_by_id"
  add_foreign_key "time_entries", "employees", column: "validated_by_id"
  add_foreign_key "time_entries", "organizations"
  add_foreign_key "weekly_schedule_plans", "employees"
  add_foreign_key "weekly_schedule_plans", "organizations"
  add_foreign_key "work_schedules", "employees"
  add_foreign_key "work_schedules", "organizations"
end
