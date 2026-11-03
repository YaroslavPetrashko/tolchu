module Markets
  # Declares the winning outcome and settles the pool: pays winners, refunds a
  # no-contest pool, credits the creator's share of the rake, and records the
  # house take. Runs once; a settled market can't be resolved again.
  class Resolve < ApplicationService
    # `now` is for tests; by default the clock is read after the market row lock is held.
    def initialize(market:, winning_outcome_id:, now: nil)
      @market = market
      @winning_outcome_id = winning_outcome_id
      @now = now
    end

    def perform
      Market.transaction do
        @market.lock!
        now = @now || Time.current
        fail!("This market has already been settled") if @market.settled?
        fail!("Betting is still open. Lock the market before declaring the result") unless @market.awaiting_result?(now)
        winner = @market.outcomes.find_by(id: @winning_outcome_id) or fail!("Pick the outcome that actually happened")

        bets = @market.bets.includes(:user).order(:id).to_a
        settlement = settle(bets, winner)
        @market.update!(
          status: :resolved,
          winning_outcome: winner,
          locked_at: @market.locked_at || @market.locks_at,
          resolved_at: now,
          refunded: settlement.refunded?,
          house_take: settlement.house_take,
          creator_reward: settlement.creator_reward
        )
        @market
      end
    end

    private
      def settle(bets, winner)
        settlement = Parimutuel::Settlement.new(
          wagers: bets.map { |bet| Parimutuel::Wager.new(id: bet.id, outcome_id: bet.outcome_id, stake: bet.stake) },
          winning_outcome_id: winner.id,
          outcome_ids: @market.outcomes.map(&:id)
        )
        lock_users_in_id_order(bets)

        bets.each do |bet|
          payout = settlement.payout_for(bet.id)
          bet.update!(payout:, status: bet_status(bet, winner, settlement))
          next if payout.zero?

          bet.user.wallet.credit!(payout, kind: settlement.refunded? ? :refund : :payout, market: @market, bet:)
        end
        @market.creator.wallet.credit!(settlement.creator_reward, kind: :creator_reward, market: @market) if settlement.creator_reward.positive?
        settlement
      end

      def bet_status(bet, winner, settlement)
        return :refunded if settlement.refunded?

        bet.outcome_id == winner.id ? :won : :lost
      end

      # Taking every row lock in a fixed order prevents deadlocks between settlements running in parallel.
      def lock_users_in_id_order(bets)
        User.where(id: bets.map(&:user_id) << @market.creator_id).order(:id).lock.load
      end
  end
end
