require "rails_helper"

RSpec.describe Betting::PlaceBet do
  let(:market) { create(:market, outcome_labels: [ "Lands it", "Bails" ]) }
  let(:user) { create(:user, balance: 500) }
  let(:lands_it) { outcome(market, "Lands it") }

  def call(stake: 40, outcome_id: lands_it.id, as: user)
    described_class.call(user: as, market:, outcome_id:, stake:)
  end

  context "with a valid prediction" do
    it "succeeds and returns the bet" do
      result = call

      expect(result).to be_success
      expect(result.value).to have_attributes(user:, outcome: lands_it, stake: 40, status: "pending")
    end

    it "debits the stake and records it in the ledger" do
      result = call

      expect(user.reload.balance).to eq(460)
      expect(user.ledger_entries.sole).to have_attributes(kind: "stake", amount: -40, balance_after: 460, market:, bet: result.value)
    end

    it "grows the outcome pool, market pool, and prediction count" do
      call
      market.reload

      expect(lands_it.reload.pool).to eq(40)
      expect(market.total_pool).to eq(40)
      expect(market.bets_count).to eq(1)
    end
  end

  shared_examples "a rejected bet" do |message|
    it "fails with a helpful message and changes nothing" do
      result = perform

      expect(result).to be_failure
      expect(result.error).to include(message)
      expect(user.reload.balance).to eq(starting_balance)
      expect(market.reload.total_pool).to eq(starting_pool)
      expect(user.ledger_entries.where(kind: :stake).count).to eq(starting_stakes)
    end
  end

  let(:starting_balance) { 500 }
  let(:starting_pool) { 0 }
  let(:starting_stakes) { 0 }

  context "when the stake is over the cap" do
    let(:perform) { call(stake: 101) }

    it_behaves_like "a rejected bet", "Stake must be less than or equal to 100"
  end

  context "when the stake isn't a positive number" do
    let(:perform) { call(stake: nil) }

    it_behaves_like "a rejected bet", "Stake is not a number"
  end

  context "when the user can't afford the stake" do
    let(:user) { create(:user, balance: 30) }
    let(:starting_balance) { 30 }
    let(:perform) { call(stake: 50) }

    it_behaves_like "a rejected bet", "You don't have enough credits for that stake (balance: 30)"
  end

  context "when no outcome is picked" do
    let(:perform) { call(outcome_id: nil) }

    it_behaves_like "a rejected bet", "Pick one of the outcomes"
  end

  context "when the outcome belongs to another market" do
    let(:perform) { call(outcome_id: create(:market).outcomes.first.id) }

    it_behaves_like "a rejected bet", "Pick one of the outcomes"
  end

  context "when the market's deadline has passed" do
    let(:perform) { travel_to(market.locks_at + 1.second) { call } }

    it_behaves_like "a rejected bet", "Betting is closed for this market"
  end

  context "when the creator locked the market early" do
    let(:perform) do
      Markets::Lock.call(market:)
      call
    end

    it_behaves_like "a rejected bet", "Betting is closed for this market"
  end

  context "when the user already predicted on this market" do
    before { call(stake: 10) }

    let(:starting_balance) { 490 }
    let(:starting_pool) { 10 }
    let(:starting_stakes) { 1 }
    let(:perform) { call(stake: 20, outcome_id: outcome(market, "Bails").id) }

    it_behaves_like "a rejected bet", "You already made a prediction on this market"
  end

  context "when the creator tries to bet on their own market" do
    let(:user) { market.creator }
    let(:starting_balance) { User::STARTING_CREDITS }
    let(:perform) { call }

    it_behaves_like "a rejected bet", "Creators can't bet on their own markets"
  end

  it "turns a race on the unique index into a friendly error" do
    allow_any_instance_of(Bet).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

    result = call
    expect(result.error).to eq("You already made a prediction on this market")
    expect(user.reload.balance).to eq(500)
  end
end
