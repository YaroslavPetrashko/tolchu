require "rails_helper"

RSpec.describe Markets::Cancel do
  let(:market) { create(:market) }
  let(:alice) { create(:user, balance: 1_000) }
  let(:bob) { create(:user, balance: 1_000) }

  before do
    place_bet(user: alice, market:, outcome: "Lands it", stake: 70)
    place_bet(user: bob, market:, outcome: "Bails", stake: 30)
  end

  it "refunds every stake in full and records the refunds" do
    expect(described_class.call(market:)).to be_success

    expect([ alice, bob ].map { |u| u.reload.balance }).to eq([ 1_000, 1_000 ])
    expect(alice.bets.sole).to have_attributes(status: "refunded", payout: 70)
    expect(bob.ledger_entries.refund.sole.amount).to eq(30)
  end

  it "marks the market cancelled with no fee or reward" do
    freeze_time do
      described_class.call(market:)

      expect(market.reload).to have_attributes(status: "cancelled", cancelled_at: Time.current, refunded: true,
                                               house_take: 0, creator_reward: 0)
    end
  end

  it "works on a locked market too" do
    Markets::Lock.call(market:)

    expect(described_class.call(market:)).to be_success
  end

  it "can't cancel a market that has already been settled" do
    Markets::Lock.call(market:)
    Markets::Resolve.call(market:, winning_outcome_id: outcome(market, "Lands it").id)

    expect(described_class.call(market:).error).to eq("This market has already been settled")
  end
end
