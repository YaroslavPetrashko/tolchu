# The only way credits move. Each movement locks the user's row, updates the
# cached balance, and appends a LedgerEntry, all in the caller's transaction.
class Wallet
  class InsufficientCredits < StandardError; end

  attr_reader :user

  def initialize(user)
    @user = user
  end

  delegate :balance, to: :user

  def credit!(amount, kind:, market: nil, bet: nil)
    post!(positive!(amount), kind:, market:, bet:)
  end

  def debit!(amount, kind:, market: nil, bet: nil)
    post!(-positive!(amount), kind:, market:, bet:)
  end

  private
    def post!(delta, kind:, market:, bet:)
      User.transaction do
        user.lock!
        new_balance = user.balance + delta
        raise InsufficientCredits, "Balance of #{user.balance} can't cover #{-delta}" if new_balance.negative?

        user.update_columns(balance: new_balance, updated_at: Time.current)
        user.ledger_entries.create!(amount: delta, balance_after: new_balance, kind:, market:, bet:)
      end
    end

    def positive!(amount)
      raise ArgumentError, "amount must be a positive integer, got #{amount.inspect}" unless amount.is_a?(Integer) && amount.positive?

      amount
    end
end
