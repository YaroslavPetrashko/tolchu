# A single prediction: one user, one market, one outcome, one stake.
# Create bets through Betting::PlaceBet, which also debits the wallet and
# updates the cached pools inside a single locked transaction.
class Bet < ApplicationRecord
  MIN_STAKE = 1
  # Hard per-user, per-market cap so no single bettor can dominate (or manipulate) a pool.
  MAX_STAKE = 100
  QUICK_STAKES = [ 10, 25, 50, 100 ].freeze

  belongs_to :user
  belongs_to :market, counter_cache: true
  belongs_to :outcome

  enum :status, { pending: "pending", won: "won", lost: "lost", refunded: "refunded" },
       default: :pending, validate: true

  validates :stake, numericality: { only_integer: true,
                                    greater_than_or_equal_to: MIN_STAKE,
                                    less_than_or_equal_to: MAX_STAKE }
  validate :one_prediction_per_market, on: :create
  validate :outcome_must_belong_to_market
  validate :creator_cannot_bet_on_own_market, on: :create
  validate :market_must_be_accepting_bets, on: :create

  # Profit or loss once settled (payout minus stake); nil while pending.
  def net
    payout - stake if payout
  end

  private
    def one_prediction_per_market
      return unless user && market && Bet.exists?(user:, market:)

      errors.add(:base, "You already made a prediction on this market")
    end

    def outcome_must_belong_to_market
      return unless outcome && market && outcome.market_id != market.id

      errors.add(:outcome, "isn't an option in this market")
    end

    def creator_cannot_bet_on_own_market
      return unless user && market && market.creator_id == user.id

      errors.add(:base, "Creators can't bet on their own markets")
    end

    def market_must_be_accepting_bets
      return unless market && !market.accepting_bets?

      errors.add(:base, "Betting is closed for this market")
    end
end
