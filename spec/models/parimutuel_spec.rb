require "rails_helper"

RSpec.describe Parimutuel do
  describe ".contest_score" do
    it "is 1 when the pool is split perfectly evenly" do
      expect(described_class.contest_score([ 50, 50 ])).to eq(1)
      expect(described_class.contest_score([ 30, 30, 30 ])).to eq(1)
    end

    it "is 0 when all the money is on one outcome" do
      expect(described_class.contest_score([ 100, 0 ])).to eq(0)
    end

    it "scales linearly with how far the favourite is from an even split" do
      expect(described_class.contest_score([ 150, 50 ])).to eq(Rational(1, 2))
      expect(described_class.contest_score([ 100, 20 ])).to eq(Rational(1, 3))
    end

    it "accounts for outcomes nobody backed" do
      expect(described_class.contest_score([ 50, 50, 0 ])).to eq(Rational(3, 4))
    end

    it "is 0 for an empty pool or a single outcome" do
      expect(described_class.contest_score([ 0, 0 ])).to eq(0)
      expect(described_class.contest_score([ 100 ])).to eq(0)
    end
  end

  describe ".rake_for" do
    it "takes 5% of the pool, rounded down" do
      expect(described_class.rake_for(total_pool: 200, losing_pool: 100)).to eq(10)
      expect(described_class.rake_for(total_pool: 199, losing_pool: 100)).to eq(9)
    end

    it "never takes more than the losing side staked" do
      expect(described_class.rake_for(total_pool: 102, losing_pool: 2)).to eq(2)
    end
  end

  describe ".creator_reward_for" do
    it "pays the creator up to half the rake, scaled by the contest score" do
      expect(described_class.creator_reward_for(rake: 10, contest_score: 1)).to eq(5)
      expect(described_class.creator_reward_for(rake: 10, contest_score: Rational(1, 2))).to eq(2)
      expect(described_class.creator_reward_for(rake: 10, contest_score: 0)).to eq(0)
    end
  end

  describe ".projected_multiplier" do
    it "returns the payout per credit if the outcome wins" do
      # 200 pool, 100 on this outcome: 190 distributable / 100 = 1.9x
      expect(described_class.projected_multiplier(outcome_pool: 100, total_pool: 200)).to eq(Rational(19, 10))
    end

    it "includes a prospective stake in both the outcome and total pools" do
      # 100 + 100 on this outcome, 300 total: rake 15, 285 / 200
      expect(described_class.projected_multiplier(outcome_pool: 100, total_pool: 200, stake: 100)).to eq(Rational(285, 200))
    end

    it "is nil when nobody has backed the outcome yet" do
      expect(described_class.projected_multiplier(outcome_pool: 0, total_pool: 50)).to be_nil
    end

    it "is exactly 1 when nobody has bet against the outcome (stakes would be refunded)" do
      expect(described_class.projected_multiplier(outcome_pool: 0, total_pool: 0, stake: 10)).to eq(1)
    end
  end
end
