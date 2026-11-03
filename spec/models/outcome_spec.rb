require "rails_helper"

RSpec.describe Outcome do
  subject { build(:outcome) }

  it { is_expected.to belong_to(:market) }
  it { is_expected.to have_many(:bets) }
  it { is_expected.to validate_presence_of(:label) }
  it { is_expected.to validate_length_of(:label).is_at_most(40) }
  it { is_expected.to validate_numericality_of(:pool).only_integer.is_greater_than_or_equal_to(0) }

  it "strips whitespace from labels" do
    expect(build(:outcome, label: "  Swish ").label).to eq("Swish")
  end

  describe "#share_of_pool" do
    let(:market) { create(:market) }

    it "is zero when the market has no money yet" do
      expect(outcome(market, "Lands it").share_of_pool).to eq(0.0)
    end

    it "is the fraction of the pool on this outcome" do
      place_bet(user: create(:user), market:, outcome: "Lands it", stake: 30)
      place_bet(user: create(:user), market:, outcome: "Bails", stake: 90)

      expect(outcome(market, "Lands it").share_of_pool).to eq(0.25)
    end
  end

  describe "#winner?" do
    it "is true only for the market's winning outcome" do
      market = create(:market)
      winner = outcome(market, "Lands it")
      market.update_columns(winning_outcome_id: winner.id)

      expect(winner.reload.winner?).to be(true)
      expect(outcome(market, "Bails").winner?).to be(false)
    end
  end
end
