class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :username, null: false
      t.string :password_digest, null: false
      # Play-money credits. Every change is mirrored by a row in ledger_entries.
      t.integer :balance, null: false, default: 0

      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_index :users, "lower(username)", unique: true, name: "index_users_on_lower_username"
    add_check_constraint :users, "balance >= 0", name: "users_balance_non_negative"
  end
end
