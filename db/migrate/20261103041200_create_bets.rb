class CreateBets < ActiveRecord::Migration[8.1]
  def change
    create_table :bets do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :market, null: false, foreign_key: true
      t.references :outcome, null: false, foreign_key: true
      t.integer :stake, null: false
      # Credits returned to the bettor at settlement (nil while pending, 0 for a loss).
      t.integer :payout
      t.string :status, null: false, default: "pending"

      t.timestamps
    end
    # One prediction per user per market, enforced by the database as well as the model.
    add_index :bets, [ :user_id, :market_id ], unique: true
    add_check_constraint :bets, "stake > 0", name: "bets_stake_positive"
    add_check_constraint :bets, "status IN ('pending', 'won', 'lost', 'refunded')", name: "bets_status_check"
  end
end
