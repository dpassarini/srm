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

ActiveRecord::Schema[8.1].define(version: 2026_06_08_125607) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "currencies", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "symbol", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_currencies_on_code", unique: true
  end

  create_table "exchange_rates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "from_currency_id", null: false
    t.decimal "rate", precision: 18, scale: 8, null: false
    t.date "reference_date", null: false
    t.bigint "to_currency_id", null: false
    t.datetime "updated_at", null: false
    t.index ["from_currency_id", "to_currency_id", "reference_date"], name: "index_exchange_rates_on_currencies_and_date", unique: true
    t.index ["from_currency_id"], name: "index_exchange_rates_on_from_currency_id"
    t.index ["to_currency_id"], name: "index_exchange_rates_on_to_currency_id"
  end

  create_table "operations", force: :cascade do |t|
    t.string "assignee", null: false
    t.datetime "created_at", null: false
    t.bigint "payment_currency_id", null: false
    t.decimal "total_face_value", precision: 18, scale: 4, null: false
    t.decimal "total_net_value", precision: 18, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["payment_currency_id"], name: "index_operations_on_payment_currency_id"
  end

  create_table "receivable_types", force: :cascade do |t|
    t.decimal "base_spread", precision: 6, scale: 4, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_receivable_types_on_code", unique: true
  end

  create_table "receivables", force: :cascade do |t|
    t.decimal "base_rate_applied", precision: 6, scale: 4, null: false
    t.datetime "created_at", null: false
    t.bigint "currency_id", null: false
    t.integer "days_to_maturity", null: false
    t.date "due_date", null: false
    t.decimal "exchange_rate_applied", precision: 18, scale: 8
    t.decimal "face_value", precision: 18, scale: 4, null: false
    t.string "identifier", null: false
    t.decimal "net_value", precision: 18, scale: 4, null: false
    t.bigint "operation_id", null: false
    t.bigint "receivable_type_id", null: false
    t.decimal "spread_applied", precision: 6, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["currency_id"], name: "index_receivables_on_currency_id"
    t.index ["operation_id"], name: "index_receivables_on_operation_id"
    t.index ["receivable_type_id"], name: "index_receivables_on_receivable_type_id"
  end

  add_foreign_key "exchange_rates", "currencies", column: "from_currency_id"
  add_foreign_key "exchange_rates", "currencies", column: "to_currency_id"
  add_foreign_key "operations", "currencies", column: "payment_currency_id"
  add_foreign_key "receivables", "currencies"
  add_foreign_key "receivables", "operations"
  add_foreign_key "receivables", "receivable_types"
end
