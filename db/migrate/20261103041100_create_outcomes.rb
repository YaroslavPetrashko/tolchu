class CreateOutcomes < ActiveRecord::Migration[8.1]
  def change
    create_table :outcomes do |t|
      t.references :market, null: false, foreign_key: true, index: false
      t.string :label, null: false
      t.integer :position, null: false, default: 0
      # Cached sum of stakes on this outcome.
      t.integer :pool, null: false, default: 0

      t.timestamps
    end
    add_index :outcomes, [ :market_id, :position ]
    add_check_constraint :outcomes, "pool >= 0", name: "outcomes_pool_non_negative"
    add_foreign_key :markets, :outcomes, column: :winning_outcome_id
  end
end
