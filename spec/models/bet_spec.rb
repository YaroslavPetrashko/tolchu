require "rails_helper"

RSpec.describe Bet do
  let(:market) { create(:market) }
  let(:user) { create(:user) }

  def build_bet(**overrides)
    build(:bet, { market:, user:, outcome: market.outcomes.first }.merge(overrides))
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:market).counter_cache(true) }
  it { is_expected.to belong_to(:outcome) }

  describe "stake limits" do
    it "accepts stakes from 1 up to the cap" do
      expect(build_bet(stake: 1)).to be_valid
      expect(build_bet(stake: Bet::MAX_STAKE)).to be_valid
    end

    it "rejects stakes above the per-market cap" do
      bet = build_bet(stake: Bet::MAX_STAKE + 1)
      expect(bet).not_to be_valid
      expect(bet.errors.full_messages).to include("Stake must be less than or equal to 100")
    end

    it "rejects zero, negative, fractional, and missing stakes" do
      [ 0, -5, 2.5, nil ].each { |stake| expect(build_bet(stake:)).not_to be_valid }
    end
  end

  it "allows only one prediction per user per market" do
    build_bet.save!
    duplicate = build_bet(outcome: market.outcomes.last)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors.full_messages).to include("You already made a prediction on this market")
  end

  it "backs the one-prediction rule with a unique index" do
    build_bet.save!
    expect { build_bet.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "requires the outcome to belong to the same market" do
    bet = build_bet(outcome: create(:market).outcomes.first)

    expect(bet).not_to be_valid
    expect(bet.errors.full_messages).to include("Outcome isn't an option in this market")
  end

  it "doesn't let creators bet on their own markets" do
    bet = build_bet(user: market.creator)

    expect(bet).not_to be_valid
    expect(bet.errors.full_messages).to include("Creators can't bet on their own markets")
  end

  it "refuses new bets once the market's deadline has passed" do
    travel_to(market.locks_at + 1.second) do
      bet = build_bet
      expect(bet).not_to be_valid
      expect(bet.errors.full_messages).to include("Betting is closed for this market")
    end
  end

  it "only applies the open-market rule when the bet is created" do
    bet = build_bet
    bet.save!
    market.update_columns(status: "locked")

    expect(bet.reload.update(status: :won, payout: 20)).to be(true)
  end

  describe "#net" do
    it "is nil while pending and payout minus stake once settled" do
      bet = build_bet(stake: 40)
      expect(bet.net).to be_nil
      bet.payout = 76
      expect(bet.net).to eq(36)
      bet.payout = 0
      expect(bet.net).to eq(-40)
    end
  end
end
