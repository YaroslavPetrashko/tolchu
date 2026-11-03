class CreateMarkets < ActiveRecord::Migration[8.1]
  def change
    create_table :markets do |t|
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.string :question, null: false
      t.text :description
      t.string :video_url, null: false
      # Second in the clip right before the action. The player freezes here until the market settles.
      t.decimal :freeze_at, precision: 6, scale: 2, null: false, default: 0
      # Betting deadline. The server rejects bets at or after this instant, whatever the status column says.
      t.datetime :locks_at, null: false
      t.string :status, null: false, default: "open"
      t.datetime :locked_at
      t.datetime :resolved_at
      t.datetime :cancelled_at
      t.bigint :winning_outcome_id
      # Cached aggregates, incremented atomically when bets are placed.
      t.integer :total_pool, null: false, default: 0
      t.integer :bets_count, null: false, default: 0
      # Settlement results (nil until the market is resolved).
      t.integer :house_take
      t.integer :creator_reward
      t.boolean :refunded, null: false, default: false

      t.timestamps
    end
    add_index :markets, [ :status, :locks_at ]
    add_index :markets, :winning_outcome_id
    add_check_constraint :markets, "status IN ('open', 'locked', 'resolved', 'cancelled')", name: "markets_status_check"
    add_check_constraint :markets, "total_pool >= 0", name: "markets_total_pool_non_negative"
  end
end
