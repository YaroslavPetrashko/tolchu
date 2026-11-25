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

  context "with a sealed answer" do
    let(:market) { create(:market, creator:, outcome_labels: [ "Swish", "Brick" ], sealed_answer_label: "Swish") }

    before do
      place_bet(user: alice, market:, outcome: "Swish", stake: 100)
      place_bet(user: carol, market:, outcome: "Brick", stake: 100)
    end

    [ :early_lock, :deadline, :expired ].each do |phase|
      context "at #{phase}" do
        let(:now) do
          case phase
          when :early_lock then Time.current
          when :expired then market.locks_at + 1.second
          else market.locks_at
          end
        end

        before { Markets::Lock.call(market:) if phase == :early_lock }

        it "rejects another outcome without changing any settlement records" do
          state = -> {
            [ market.reload.attributes, market.outcomes.map(&:attributes), market.bets.order(:id).map(&:attributes),
              [ creator, alice, carol ].map { |user| user.reload.attributes }, LedgerEntry.order(:id).map(&:attributes) ]
          }
          before_resolution = state.call

          expect(resolve("Brick", now:).error).to eq("The result must match the sealed answer")

          expect(state.call).to eq(before_resolution)
        end

        it "pays the sealed winner" do
          expect(resolve("Swish", now:)).to be_success

          expect(market.reload).to have_attributes(status: "resolved", winning_outcome: outcome(market, "Swish"))
          expect(alice.bets.sole).to have_attributes(status: "won", payout: 190)
          expect(carol.bets.sole).to have_attributes(status: "lost", payout: 0)
          expect([ alice, carol, creator ].map { |user| user.reload.balance }).to eq([ 1_090, 900, 5 ])
        end
      end
    end
  end

  it "checks the persisted seal after locking even when the caller cached no sealed answer" do
    expect(market.sealed_winner).to be_nil
    outcome(market, "Swish").update!(sealed_winner: true)
    Markets::Lock.call(market: Market.find(market.id))

    expect(resolve("Brick").error).to eq("The result must match the sealed answer")
    expect(market.reload).to be_locked
  end

  context "when the market or a bet no longer passes the publishing rules" do
    before do
      place_bet(user: alice, market:, outcome: "Swish", stake: 100)
      place_bet(user: carol, market:, outcome: "Brick", stake: 100)
      Markets::Lock.call(market:)
      market.update_columns(video_url: "ftp://old-host/clip.mp4", question: "Q" * 200)
      carol.bets.sole.update_columns(stake: Bet::MAX_STAKE + 50)
    end

    it "still settles and pays out, because those rules are about publishing, not paying" do
      expect(market.reload).not_to be_valid

      expect(resolve("Swish")).to be_success
      expect(market.reload).to be_resolved
      expect(alice.bets.sole).to be_won
      expect(carol.bets.sole).to be_lost
      expect(alice.reload.balance).to be > 1_000
    end
  end
end
