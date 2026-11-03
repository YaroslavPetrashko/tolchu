class CreateLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    # Append-only record of every credit movement. users.balance is a cache of SUM(amount).
    create_table :ledger_entries do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :market, foreign_key: true
      t.references :bet, foreign_key: true
      t.string :kind, null: false
      t.integer :amount, null: false
      t.integer :balance_after, null: false

      t.timestamps
    end
    add_index :ledger_entries, [ :user_id, :created_at ]
    add_check_constraint :ledger_entries, "amount <> 0", name: "ledger_entries_amount_non_zero"
    add_check_constraint :ledger_entries, "balance_after >= 0", name: "ledger_entries_balance_after_non_negative"
  end
end
