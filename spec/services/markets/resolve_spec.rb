require "rails_helper"

RSpec.describe Markets::Resolve do
  let(:creator) { create(:user, balance: 0) }
  let(:market) { create(:market, creator:, outcome_labels: [ "Swish", "Brick" ]) }
  let(:alice) { create(:user, username: "alice", balance: 1_000) }
  let(:bob) { create(:user, username: "bob", balance: 1_000) }
  let(:carol) { create(:user, username: "carol", balance: 1_000) }

  def resolve(winner, now: Time.current)
    described_class.call(market:, winning_outcome_id: outcome(market, winner).id, now:)
  end

  context "with bets on both sides" do
    before do
      place_bet(user: alice, market:, outcome: "Swish", stake: 100)
      place_bet(user: bob, market:, outcome: "Swish", stake: 50)
      place_bet(user: carol, market:, outcome: "Brick", stake: 50)
      Markets::Lock.call(market:)
    end

    it "marks the market resolved with the winner and settlement numbers" do
      freeze_time do
        expect(resolve("Swish")).to be_success
        expect(market.reload).to have_attributes(
          status: "resolved", winning_outcome: outcome(market, "Swish"), resolved_at: Time.current,
          house_take: 9, creator_reward: 2, refunded: false
        )
      end
    end

    it "pays winners pro rata and marks every bet won or lost" do
      resolve("Swish")

      expect(alice.bets.sole).to have_attributes(status: "won", payout: 126)
      expect(bob.bets.sole).to have_attributes(status: "won", payout: 63)
      expect(carol.bets.sole).to have_attributes(status: "lost", payout: 0)
      expect([ alice, bob, carol ].map { |u| u.reload.balance }).to eq([ 1_026, 1_013, 950 ])
    end

    it "records payouts and the creator reward in the ledger" do
      resolve("Swish")

      expect(alice.ledger_entries.payout.sole.amount).to eq(126)
      expect(carol.ledger_entries.payout).to be_empty
      expect(creator.ledger_entries.creator_reward.sole).to have_attributes(amount: 2, market:)
      expect(creator.reload.balance).to eq(2)
    end

    it "conserves credits: everything staked ends up with bettors, the creator, or the house" do
      resolve("Swish")
      market.reload

      paid_out = market.bets.sum(:payout)
      expect(paid_out + market.creator_reward + market.house_take).to eq(market.total_pool)
    end

    it "can only settle a market once" do
      resolve("Swish")

      expect(resolve("Brick").error).to eq("This market has already been settled")
      expect(alice.reload.balance).to eq(1_026)
    end

    it "requires an outcome from this market" do
      result = described_class.call(market:, winning_outcome_id: create(:market).outcomes.first.id)

      expect(result.error).to eq("Pick the outcome that actually happened")
      expect(market.reload).to be_locked
    end
  end

  it "refunds everyone, takes no fee, and pays no reward when nobody picked the winner" do
    place_bet(user: alice, market:, outcome: "Swish", stake: 100)
    place_bet(user: bob, market:, outcome: "Swish", stake: 50)
    Markets::Lock.call(market:)

    resolve("Brick")

    expect(market.reload).to have_attributes(refunded: true, house_take: 0, creator_reward: 0)
    expect(alice.bets.sole).to have_attributes(status: "refunded", payout: 100)
    expect(alice.ledger_entries.refund.sole.amount).to eq(100)
    expect([ alice, bob ].map { |u| u.reload.balance }).to eq([ 1_000, 1_000 ])
    expect(creator.ledger_entries).to be_empty
  end

  it "settles a market nobody bet on" do
    Markets::Lock.call(market:)

    expect(resolve("Swish")).to be_success
    expect(market.reload).to be_resolved
  end

  it "won't settle while betting is still open" do
    expect(resolve("Swish").error).to eq("Betting is still open. Lock the market before declaring the result")
  end

  it "settles a market whose deadline passed without an explicit lock, and backfills locked_at" do
    place_bet(user: alice, market:, outcome: "Swish", stake: 10)

    travel_to(market.locks_at + 1.minute) do
      expect(resolve("Swish")).to be_success
      expect(market.reload.locked_at).to eq(market.locks_at)
    end
  end

  it "won't settle a cancelled market" do
    Markets::Cancel.call(market:)

    expect(resolve("Swish").error).to eq("This market has already been settled")
  end
end
