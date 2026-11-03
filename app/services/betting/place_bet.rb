module Betting
  # Places one prediction atomically: validates it, debits the stake, and grows
  # the outcome and market pools. The market row is locked first so a bet can't
  # race past an early lock or a settlement.
  class PlaceBet < ApplicationService
    def initialize(user:, market:, outcome_id:, stake:)
      @user = user
      @market = market
      @outcome_id = outcome_id
      @stake = stake
    end

    def perform
      bet = Market.transaction do
        @market.lock!
        outcome = @market.outcomes.find_by(id: @outcome_id) or fail!("Pick one of the outcomes before placing your bet")

        bet = @market.bets.build(user: @user, outcome:, stake: @stake)
        fail!(bet.errors.full_messages.to_sentence) unless bet.save

        debit_stake(bet)
        Outcome.update_counters(outcome.id, pool: bet.stake)
        Market.update_counters(@market.id, total_pool: bet.stake)
        bet
      end
      @market.reload # pick up the counters incremented in SQL
      bet
    rescue ActiveRecord::RecordNotUnique
      fail!("You already made a prediction on this market")
    end

    private
      def debit_stake(bet)
        @user.wallet.debit!(bet.stake, kind: :stake, market: @market, bet:)
      rescue Wallet::InsufficientCredits
        fail!("You don't have enough credits for that stake (balance: #{@user.reload.balance})")
      end
  end
end
