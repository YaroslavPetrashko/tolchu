module Parimutuel
  # Splits a pool of wagers once the winning outcome is known.
  # Invariant: payouts.values.sum + creator_reward + house_take == total_pool.
  class Settlement
    attr_reader :wagers, :winning_outcome_id, :payouts, :rake, :creator_reward, :house_take, :contest_score

    # outcome_ids lists every outcome in the market (including ones nobody bet on)
    # so the contest score accounts for the full set of options.
    def initialize(wagers:, winning_outcome_id:, outcome_ids:)
      @wagers = wagers
      @winning_outcome_id = winning_outcome_id
      @contest_score = Parimutuel.contest_score(outcome_ids.map { |id| pool_for(id) })
      settle
    end

    def refunded?
      @refunded
    end

    def payout_for(wager_id)
      payouts.fetch(wager_id)
    end

    def total_pool
      wagers.sum(&:stake)
    end

    def winning_pool
      pool_for(winning_outcome_id)
    end

    def losing_pool
      total_pool - winning_pool
    end

    private
      def settle
        if winning_pool.zero? || losing_pool.zero?
          refund_everyone
        else
          pay_winners
        end
      end

      def refund_everyone
        @refunded = true
        @payouts = wagers.to_h { |wager| [ wager.id, wager.stake ] }
        @rake = @creator_reward = @house_take = 0
      end

      def pay_winners
        @refunded = false
        @rake = Parimutuel.rake_for(total_pool:, losing_pool:)
        distributable = total_pool - rake
        @payouts = wagers.to_h do |wager|
          [ wager.id, wager.outcome_id == winning_outcome_id ? distributable * wager.stake / winning_pool : 0 ]
        end
        dust = distributable - payouts.values.sum
        @creator_reward = Parimutuel.creator_reward_for(rake:, contest_score:)
        @house_take = rake + dust - creator_reward
      end

      def pool_for(outcome_id)
        wagers.select { |wager| wager.outcome_id == outcome_id }.sum(&:stake)
      end
  end
end
