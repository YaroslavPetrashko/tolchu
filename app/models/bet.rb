class Bet < ApplicationRecord
  MIN_STAKE = 1
  MAX_STAKE = 100
  DEFAULT_STAKE = 10

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

  # Records the result of a bet without re-running the placement validations,
  # so a bet made under older limits can still be paid or refunded.
  def settle!(status:, payout:)
    assign_attributes(status:, payout:)
    save!(validate: false)
  end

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
