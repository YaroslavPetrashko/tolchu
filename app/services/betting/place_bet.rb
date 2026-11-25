module Betting
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
        # Take the bettor's row lock before the bet is inserted. The insert takes a shared lock on
        # that row (foreign key), so two bets by one user on different markets would otherwise each
        # hold the shared lock and deadlock when the wallet asks for the exclusive one.
        @user.lock!
        outcome = @market.outcomes.find_by(id: @outcome_id) or fail!("Pick one of the outcomes before placing your bet")

        bet = @market.bets.build(user: @user, outcome:, stake: @stake)
        fail!(bet.errors.full_messages.to_sentence) unless bet.save

        debit_stake(bet)
        Outcome.update_counters(outcome.id, pool: bet.stake)
        Market.update_counters(@market.id, total_pool: bet.stake)
        bet
      end
      @market.reload
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
