require "rails_helper"

RSpec.describe Parimutuel::Settlement do
  def wager(id, outcome_id, stake)
    Parimutuel::Wager.new(id:, outcome_id:, stake:)
  end

  def settle(wagers, winner: :a, outcomes: %i[a b])
    described_class.new(wagers:, winning_outcome_id: winner, outcome_ids: outcomes)
  end

  context "when both sides have money" do
    subject(:settlement) { settle([ wager(1, :a, 100), wager(2, :a, 50), wager(3, :b, 50) ]) }

    it "splits the pool minus the rake among winners in proportion to their stakes" do
      expect(settlement.payouts).to eq(1 => 126, 2 => 63, 3 => 0)
    end

    it "takes a 5% rake" do
      expect(settlement.rake).to eq(10)
    end

    it "gives the creator a share of the rake scaled by the contest score" do
      expect(settlement.contest_score).to eq(Rational(1, 2))
      expect(settlement.creator_reward).to eq(2)
    end

    it "gives rounding dust to the house" do
      # rake 10 + dust 1 - creator 2
      expect(settlement.house_take).to eq(9)
    end

    it "reports pool sizes" do
      expect(settlement).to have_attributes(total_pool: 200, winning_pool: 150, losing_pool: 50)
    end

    it { is_expected.not_to be_refunded }

    it "looks up a single payout" do
      expect(settlement.payout_for(1)).to eq(126)
      expect { settlement.payout_for(99) }.to raise_error(KeyError)
    end
  end

  it "caps the rake at the losing pool so winners always get their stake back" do
    settlement = settle([ wager(1, :a, 100), wager(2, :b, 2) ])

    expect(settlement.rake).to eq(2)
    expect(settlement.payout_for(1)).to eq(100)
  end

  it "refunds everyone with no rake when nobody picked the winner" do
    settlement = settle([ wager(1, :b, 100), wager(2, :b, 50) ], winner: :a)

    expect(settlement).to be_refunded
    expect(settlement.payouts).to eq(1 => 100, 2 => 50)
    expect([ settlement.rake, settlement.creator_reward, settlement.house_take ]).to all(eq(0))
  end

  it "refunds everyone with no rake when nobody bet against the winner" do
    settlement = settle([ wager(1, :a, 100), wager(2, :a, 50) ])

    expect(settlement).to be_refunded
    expect(settlement.payouts).to eq(1 => 100, 2 => 50)
  end

  it "handles a market with no bets" do
    settlement = settle([])

    expect(settlement).to be_refunded
    expect(settlement.payouts).to eq({})
    expect(settlement.house_take).to eq(0)
  end

  it "settles multi-outcome markets where several outcomes lose" do
    settlement = settle([ wager(1, :a, 30), wager(2, :b, 30), wager(3, :c, 40) ], winner: :b, outcomes: %i[a b c])

    # 100 pool, rake 5, 95 to the only winner
    expect(settlement.payouts).to eq(1 => 0, 2 => 95, 3 => 0)
    expect(settlement.contest_score).to eq(Rational(9, 10))
    expect(settlement.creator_reward).to eq(2)
    expect(settlement.house_take).to eq(3)
  end

  describe "invariants across random pools" do
    it "never creates or destroys credits and never pays a winner less than their stake" do
      rng = Random.new(4152)
      300.times do
        outcomes = %i[a b c d].first(rng.rand(2..4))
        wagers = Array.new(rng.rand(0..25)) { |i| wager(i, outcomes.sample(random: rng), rng.rand(1..Bet::MAX_STAKE)) }
        settlement = settle(wagers, winner: outcomes.sample(random: rng), outcomes:)

        total_out = settlement.payouts.values.sum + settlement.creator_reward + settlement.house_take
        expect(total_out).to eq(settlement.total_pool)
        expect(settlement.house_take).to be >= 0
        expect(settlement.creator_reward).to be <= settlement.rake / 2
        wagers.select { |w| w.outcome_id == settlement.winning_outcome_id }.each do |winner|
          expect(settlement.payout_for(winner.id)).to be >= winner.stake
        end
      end
    end
  end
end
