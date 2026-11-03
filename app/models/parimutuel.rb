# Pure parimutuel math, with no database access, so it is trivial to test.
#
# All stakes on a market form one pool. When the result is in:
#   * the house keeps a 5% rake, capped at the losing side's money so winners
#     always get at least their stake back;
#   * the rest is split among winning bets in proportion to their stakes
#     (rounded down; leftover "dust" goes to the house);
#   * if nobody picked the winner, or nobody bet against it, there is no
#     contest and every stake is refunded with no rake.
# The market's creator earns up to half of the rake, scaled by how contested
# (evenly split) the pool was.
module Parimutuel
  RAKE_RATE = Rational(5, 100)
  MAX_CREATOR_SHARE = Rational(1, 2)

  module_function

  # 0 when all the money sits on one outcome, 1 when it is split perfectly evenly.
  def contest_score(pools)
    total = pools.sum
    return Rational(0) if total.zero? || pools.size < 2

    max_share = Rational(pools.max, total)
    (1 - max_share) / (1 - Rational(1, pools.size))
  end

  def rake_for(total_pool:, losing_pool:)
    [ (total_pool * RAKE_RATE).floor, losing_pool ].min
  end

  def creator_reward_for(rake:, contest_score:)
    (rake * MAX_CREATOR_SHARE * contest_score).floor
  end

  # How many times its stake a bet on this outcome would return if it won,
  # assuming `stake` more credits join the outcome. nil when the outcome has no money yet.
  def projected_multiplier(outcome_pool:, total_pool:, stake: 0)
    pool = outcome_pool + stake
    total = total_pool + stake
    return nil if pool.zero?

    losing = total - pool
    return Rational(1) if losing.zero?

    Rational(total - rake_for(total_pool: total, losing_pool: losing), pool)
  end
end
