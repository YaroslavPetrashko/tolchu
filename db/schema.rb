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

ActiveRecord::Schema[8.1].define(version: 2026_11_03_041300) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "market_id", null: false
    t.bigint "outcome_id", null: false
    t.integer "stake", null: false
    t.integer "payout"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["market_id"], name: "index_bets_on_market_id"
    t.index ["outcome_id"], name: "index_bets_on_outcome_id"
    t.index ["user_id", "market_id"], name: "index_bets_on_user_id_and_market_id", unique: true
    t.check_constraint "stake > 0", name: "bets_stake_positive"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'won'::character varying, 'lost'::character varying, 'refunded'::character varying]::text[])", name: "bets_status_check"
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "market_id"
    t.bigint "bet_id"
    t.string "kind", null: false
    t.integer "amount", null: false
    t.integer "balance_after", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bet_id"], name: "index_ledger_entries_on_bet_id"
    t.index ["market_id"], name: "index_ledger_entries_on_market_id"
    t.index ["user_id", "created_at"], name: "index_ledger_entries_on_user_id_and_created_at"
    t.check_constraint "amount <> 0", name: "ledger_entries_amount_non_zero"
    t.check_constraint "balance_after >= 0", name: "ledger_entries_balance_after_non_negative"
  end

  create_table "markets", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.string "question", null: false
    t.text "description"
    t.string "video_url", null: false
    t.decimal "freeze_at", precision: 6, scale: 2, default: "0.0", null: false
    t.datetime "locks_at", null: false
    t.string "status", default: "open", null: false
    t.datetime "locked_at"
    t.datetime "resolved_at"
    t.datetime "cancelled_at"
    t.bigint "winning_outcome_id"
    t.integer "total_pool", default: 0, null: false
    t.integer "bets_count", default: 0, null: false
    t.integer "house_take"
    t.integer "creator_reward"
    t.boolean "refunded", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_markets_on_creator_id"
    t.index ["status", "locks_at"], name: "index_markets_on_status_and_locks_at"
    t.index ["winning_outcome_id"], name: "index_markets_on_winning_outcome_id"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'locked'::character varying, 'resolved'::character varying, 'cancelled'::character varying]::text[])", name: "markets_status_check"
    t.check_constraint "total_pool >= 0", name: "markets_total_pool_non_negative"
  end

  create_table "outcomes", force: :cascade do |t|
    t.bigint "market_id", null: false
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.integer "pool", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["market_id", "position"], name: "index_outcomes_on_market_id_and_position"
    t.check_constraint "pool >= 0", name: "outcomes_pool_non_negative"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "username", null: false
    t.string "password_digest", null: false
    t.integer "balance", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "balance >= 0", name: "users_balance_non_negative"
  end

  add_foreign_key "bets", "markets"
  add_foreign_key "bets", "outcomes"
  add_foreign_key "bets", "users"
  add_foreign_key "ledger_entries", "bets"
  add_foreign_key "ledger_entries", "markets"
  add_foreign_key "ledger_entries", "users"
  add_foreign_key "markets", "outcomes", column: "winning_outcome_id"
  add_foreign_key "markets", "users", column: "creator_id"
  add_foreign_key "outcomes", "markets"
  add_foreign_key "sessions", "users"
end
