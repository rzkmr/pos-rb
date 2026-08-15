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

ActiveRecord::Schema[8.1].define(version: 2026_08_15_114600) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admin_users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "locale", default: "en", null: false
    t.string "password_digest", null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["shop_id", "username"], name: "index_admin_users_on_shop_id_and_username", unique: true
    t.index ["shop_id"], name: "index_admin_users_on_shop_id"
  end

  create_table "audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "admin_user_id"
    t.datetime "created_at", null: false
    t.integer "device_id"
    t.json "payload", default: {}, null: false
    t.integer "shop_id", null: false
    t.integer "subject_id", null: false
    t.string "subject_type", null: false
    t.integer "user_id"
    t.index ["admin_user_id"], name: "index_audit_events_on_admin_user_id"
    t.index ["device_id"], name: "index_audit_events_on_device_id"
    t.index ["shop_id", "subject_type", "subject_id"], name: "index_audit_events_on_shop_id_and_subject_type_and_subject_id"
    t.index ["shop_id"], name: "index_audit_events_on_shop_id"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "client_actions", force: :cascade do |t|
    t.datetime "applied_at", null: false
    t.string "client_action_id", null: false
    t.datetime "created_at", null: false
    t.bigint "device_id"
    t.string "kind", null: false
    t.jsonb "result", default: {}, null: false
    t.bigint "shop_id", null: false
    t.string "status", default: "applied", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_client_actions_on_device_id"
    t.index ["shop_id", "client_action_id"], name: "index_client_actions_on_shop_id_and_client_action_id", unique: true
    t.index ["shop_id", "status"], name: "index_client_actions_on_shop_id_and_status"
    t.index ["shop_id"], name: "index_client_actions_on_shop_id"
  end

  create_table "devices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.datetime "last_seen_at"
    t.integer "shop_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id"], name: "index_devices_on_shop_id"
    t.index ["token_digest"], name: "index_devices_on_token_digest", unique: true
  end

  create_table "dining_tables", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.integer "seats", default: 4, null: false
    t.integer "shop_id", null: false
    t.boolean "takeaway", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "label"], name: "index_dining_tables_on_shop_id_and_label", unique: true
    t.index ["shop_id"], name: "index_dining_tables_on_shop_id"
  end

  create_table "held_carts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dining_table_id", null: false
    t.datetime "held_at", null: false
    t.bigint "held_by_id", null: false
    t.json "items", default: [], null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.index ["dining_table_id"], name: "index_held_carts_on_dining_table_id"
    t.index ["held_by_id"], name: "index_held_carts_on_held_by_id"
    t.index ["shop_id", "dining_table_id"], name: "index_held_carts_on_shop_id_and_dining_table_id"
    t.index ["shop_id"], name: "index_held_carts_on_shop_id"
  end

  create_table "invoice_authority_grants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "device_id", null: false
    t.datetime "expires_at", null: false
    t.string "financial_year", null: false
    t.datetime "granted_at", null: false
    t.integer "granted_sequence", null: false
    t.integer "last_reported_sequence"
    t.datetime "reconciled_at"
    t.datetime "released_at"
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_invoice_authority_grants_on_device_id"
    t.index ["shop_id", "device_id"], name: "index_invoice_authority_grants_on_shop_id_and_device_id"
    t.index ["shop_id"], name: "idx_one_live_grant_per_shop", unique: true, where: "(released_at IS NULL)"
    t.index ["shop_id"], name: "index_invoice_authority_grants_on_shop_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "cgst_paise", null: false
    t.datetime "created_at", null: false
    t.string "customer_gstin"
    t.string "customer_name"
    t.string "financial_year", null: false
    t.string "gstin_snapshot"
    t.datetime "issued_at", null: false
    t.string "number", null: false
    t.integer "print_count", default: 0, null: false
    t.datetime "printed_at"
    t.integer "round_off_paise", default: 0, null: false
    t.integer "sequence", null: false
    t.integer "sgst_paise", null: false
    t.integer "shop_id", null: false
    t.integer "table_session_id", null: false
    t.integer "taxable_paise", null: false
    t.integer "total_paise", null: false
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_invoices_on_number", unique: true
    t.index ["shop_id", "financial_year", "sequence"], name: "index_invoices_on_shop_id_and_financial_year_and_sequence", unique: true
    t.index ["shop_id"], name: "index_invoices_on_shop_id"
    t.index ["table_session_id"], name: "index_invoices_on_table_session_id"
  end

  create_table "menu_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "hsn_sac", default: "996331", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "price_paise", null: false
    t.integer "shop_id", null: false
    t.datetime "updated_at", null: false
    t.json "variants", default: [], null: false
    t.index ["shop_id", "active"], name: "index_menu_items_on_shop_id_and_active"
    t.index ["shop_id"], name: "index_menu_items_on_shop_id"
  end

  create_table "pairing_attempts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address", null: false
    t.bigint "shop_id", null: false
    t.boolean "success", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "success", "created_at"], name: "index_pairing_attempts_on_shop_id_and_success_and_created_at"
    t.index ["shop_id"], name: "index_pairing_attempts_on_shop_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_paise", null: false
    t.string "client_token"
    t.datetime "created_at", null: false
    t.string "method", null: false
    t.integer "received_by_id", null: false
    t.string "reference"
    t.integer "shop_id", null: false
    t.integer "table_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["client_token"], name: "index_payments_on_client_token", unique: true, where: "(client_token IS NOT NULL)"
    t.index ["received_by_id"], name: "index_payments_on_received_by_id"
    t.index ["shop_id", "table_session_id"], name: "index_payments_on_shop_id_and_table_session_id"
    t.index ["shop_id"], name: "index_payments_on_shop_id"
    t.index ["table_session_id"], name: "index_payments_on_table_session_id"
  end

  create_table "print_jobs", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "invoice_id", null: false
    t.string "kind", null: false
    t.text "last_error"
    t.datetime "sent_at"
    t.integer "shop_id", null: false
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_print_jobs_on_invoice_id"
    t.index ["shop_id", "status"], name: "index_print_jobs_on_shop_id_and_status"
    t.index ["shop_id"], name: "index_print_jobs_on_shop_id"
  end

  create_table "shops", force: :cascade do |t|
    t.string "address"
    t.boolean "composition_scheme", default: false, null: false
    t.datetime "created_at", null: false
    t.string "fssai_licence"
    t.integer "gst_rate_bp", default: 500, null: false
    t.string "gstin"
    t.text "invoice_footer"
    t.string "invoice_fy", null: false
    t.string "invoice_prefix", default: "INV", null: false
    t.integer "invoice_sequence", default: 0, null: false
    t.string "name", null: false
    t.string "pairing_pin"
    t.boolean "prices_include_tax", default: false, null: false
    t.string "printer_host"
    t.integer "printer_port", default: 9100, null: false
    t.string "state_code", null: false
    t.datetime "updated_at", null: false
  end

  create_table "table_sessions", force: :cascade do |t|
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.integer "dining_table_id", null: false
    t.integer "discount_approved_by_id"
    t.integer "discount_paise", default: 0, null: false
    t.string "discount_reason"
    t.datetime "opened_at", null: false
    t.integer "opened_by_id", null: false
    t.integer "shop_id", null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.index ["dining_table_id"], name: "index_table_sessions_on_dining_table_id"
    t.index ["discount_approved_by_id"], name: "index_table_sessions_on_discount_approved_by_id"
    t.index ["opened_by_id"], name: "index_table_sessions_on_opened_by_id"
    t.index ["shop_id", "status"], name: "index_table_sessions_on_shop_id_and_status"
    t.index ["shop_id"], name: "index_table_sessions_on_shop_id"
  end

  create_table "ticket_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hsn_sac_snapshot", null: false
    t.integer "menu_item_id", null: false
    t.string "name_snapshot", null: false
    t.text "notes"
    t.integer "quantity", default: 1, null: false
    t.integer "ticket_id", null: false
    t.integer "unit_price_paise", null: false
    t.datetime "updated_at", null: false
    t.string "variant_name"
    t.string "void_reason"
    t.datetime "voided_at"
    t.integer "voided_by_id"
    t.index ["menu_item_id"], name: "index_ticket_items_on_menu_item_id"
    t.index ["ticket_id"], name: "index_ticket_items_on_ticket_id"
    t.index ["voided_by_id"], name: "index_ticket_items_on_voided_by_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.string "client_token", null: false
    t.datetime "created_at", null: false
    t.integer "number", null: false
    t.datetime "placed_at", null: false
    t.integer "placed_by_id", null: false
    t.integer "shop_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "table_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["client_token"], name: "index_tickets_on_client_token", unique: true
    t.index ["placed_by_id"], name: "index_tickets_on_placed_by_id"
    t.index ["shop_id", "status"], name: "index_tickets_on_shop_id_and_status"
    t.index ["shop_id"], name: "index_tickets_on_shop_id"
    t.index ["table_session_id", "number"], name: "index_tickets_on_table_session_id_and_number", unique: true
    t.index ["table_session_id"], name: "index_tickets_on_table_session_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "locale", default: "ne", null: false
    t.string "name", null: false
    t.string "pin"
    t.string "role", null: false
    t.integer "shop_id", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "role"], name: "index_users_on_shop_id_and_role"
    t.index ["shop_id"], name: "index_users_on_shop_id"
  end

  add_foreign_key "admin_users", "shops"
  add_foreign_key "audit_events", "admin_users"
  add_foreign_key "audit_events", "devices"
  add_foreign_key "audit_events", "shops"
  add_foreign_key "audit_events", "users"
  add_foreign_key "client_actions", "devices"
  add_foreign_key "client_actions", "shops"
  add_foreign_key "devices", "shops"
  add_foreign_key "dining_tables", "shops"
  add_foreign_key "held_carts", "dining_tables"
  add_foreign_key "held_carts", "shops"
  add_foreign_key "held_carts", "users", column: "held_by_id"
  add_foreign_key "invoice_authority_grants", "devices"
  add_foreign_key "invoice_authority_grants", "shops"
  add_foreign_key "invoices", "shops"
  add_foreign_key "invoices", "table_sessions"
  add_foreign_key "menu_items", "shops"
  add_foreign_key "pairing_attempts", "shops"
  add_foreign_key "payments", "shops"
  add_foreign_key "payments", "table_sessions"
  add_foreign_key "payments", "users", column: "received_by_id"
  add_foreign_key "print_jobs", "invoices"
  add_foreign_key "print_jobs", "shops"
  add_foreign_key "table_sessions", "dining_tables"
  add_foreign_key "table_sessions", "shops"
  add_foreign_key "table_sessions", "users", column: "discount_approved_by_id"
  add_foreign_key "table_sessions", "users", column: "opened_by_id"
  add_foreign_key "ticket_items", "menu_items"
  add_foreign_key "ticket_items", "tickets"
  add_foreign_key "ticket_items", "users", column: "voided_by_id"
  add_foreign_key "tickets", "shops"
  add_foreign_key "tickets", "table_sessions"
  add_foreign_key "tickets", "users", column: "placed_by_id"
  add_foreign_key "users", "shops"
end
