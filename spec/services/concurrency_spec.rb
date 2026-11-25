require "rails_helper"

# Every thread loads its own records: Active Record objects are never shared between threads.
RSpec.describe "Betting under real concurrency", :concurrency do
  def bet_from(user_id:, market_id:, label: "Lands it", stake: 30)
    market = Market.find(market_id)
    Betting::PlaceBet.call(user: User.find(user_id), market:, outcome_id: market.outcomes.find_by!(label:).id, stake:)
  end

  def lock_now(market)
    market.update_columns(status: "locked", locks_at: 1.second.ago, locked_at: 1.second.ago)
  end

  def expect_ledger_to_match_balances
    User.find_each do |user|
      expect(user.balance).to eq(User::STARTING_CREDITS + user.ledger_entries.sum(:amount)).or eq(100 + user.ledger_entries.sum(:amount))
      expect(user.balance).to be >= 0
    end
  end

  def expect_credits_conserved(market)
    market.reload
    expect(market.bets.sum(:payout) + market.creator_reward + market.house_take).to eq(market.total_pool)
    market.bets.each do |bet|
      expect(LedgerEntry.where(bet:, kind: %w[payout refund]).count).to be <= 1
    end
  end

  it "accepts one bet when the same user submits the same market from five threads" do
    user = create(:user)
    market = create(:market)

    results = in_parallel(5) { bet_from(user_id: user.id, market_id: market.id) }

    expect(results.count(&:success?)).to eq(1)
    expect(results.reject(&:success?).map(&:error)).to all(eq("You already made a prediction on this market"))
    expect(user.ledger_entries.where(kind: "stake").count).to eq(1)
    expect(market.reload).to have_attributes(total_pool: 30, bets_count: 1)
    expect(user.reload.balance).to eq(User::STARTING_CREDITS - 30)
  end

  it "never lets a balance go negative when one user bets on five markets at once" do
    user = create(:user, balance: 100)
    markets = create_list(:market, 5)

    results = in_parallel(5) { |index| bet_from(user_id: user.id, market_id: markets[index].id) }

    expect(results.count(&:success?)).to eq(3)
    expect(results.reject(&:success?).map(&:error)).to all(start_with("You don't have enough credits"))
    expect(user.reload.balance).to eq(10)
    expect(user.ledger_entries.sum(:amount)).to eq(-90)
  end

  it "keeps every accepted bet inside the betting window when bets race the lock" do
    market = create(:market)
    bettors = create_list(:user, 4)

    results = in_parallel(5) do |index|
      index == 4 ? Markets::Lock.call(market: Market.find(market.id)) : bet_from(user_id: bettors[index].id, market_id: market.id)
    end

    lock_result, bet_results = results.last, results.first(4)
    expect(lock_result).to be_success
    expect(bet_results.reject(&:success?).map(&:error)).to all(eq("Betting is closed for this market"))

    market.reload
    expect(market.bets.count).to eq(bet_results.count(&:success?))
    expect(market.total_pool).to eq(market.bets.sum(:stake))
    expect(market.outcomes.sum(:pool)).to eq(market.bets.sum(:stake))
    expect(market.bets.pluck(:created_at)).to all(be <= market.locked_at)
    expect_ledger_to_match_balances
  end

  context "with a locked, contested market" do
    let!(:market) { create(:market) }
    let!(:winner_id) { market.outcomes.find_by!(label: "Lands it").id }

    before do
      create_list(:user, 2).each { |user| place_bet(user:, market:, outcome: "Lands it", stake: 40) }
      create_list(:user, 2).each { |user| place_bet(user:, market:, outcome: "Bails", stake: 60) }
      lock_now(market)
    end

    it "pays out once when the result is declared twice at the same moment" do
      results = in_parallel(2) { Markets::Resolve.call(market: Market.find(market.id), winning_outcome_id: winner_id) }

      expect(results.count(&:success?)).to eq(1)
      expect(results.find(&:failure?).error).to eq("This market has already been settled")
      expect(market.reload).to be_resolved
      expect_credits_conserved(market)
      expect_ledger_to_match_balances
    end

    [ "Lands it", "Bails" ].each do |manual_winner|
      it "settles only the sealed answer once when automatic settlement races a manual #{manual_winner} result" do
        market.outcomes.find(winner_id).update!(sealed_winner: true)
        manual_winner_id = outcome(market, manual_winner).id

        results = in_parallel(2) do |index|
          if index.zero?
            Markets::SettleSealed.call(scope: Market.where(id: market.id))
          else
            Markets::Resolve.call(market: Market.find(market.id), winning_outcome_id: manual_winner_id)
          end
        end

        automatic, manual = results
        expect(automatic).to be_success
        expect(automatic.value + (manual.success? ? 1 : 0)).to eq(1)
        expect(manual).to be_failure if manual_winner == "Bails"
        expect(market.reload).to have_attributes(status: "resolved", winning_outcome_id: winner_id)
        expect(market.bets.where(outcome_id: winner_id).pluck(:status, :payout)).to eq([ [ "won", 95 ], [ "won", 95 ] ])
        expect(market.bets.where.not(outcome_id: winner_id).pluck(:status, :payout)).to eq([ [ "lost", 0 ], [ "lost", 0 ] ])
        expect(LedgerEntry.where(market:, kind: :payout).count).to eq(2)
        expect(LedgerEntry.where(market:, kind: :creator_reward).count).to eq(1)
        expect_credits_conserved(market)
        expect_ledger_to_match_balances
      end
    end

    it "either pays out or refunds, never both, when declaring races cancelling" do
      results = in_parallel(2) do |index|
        fresh = Market.find(market.id)
        index.zero? ? Markets::Resolve.call(market: fresh, winning_outcome_id: winner_id) : Markets::Cancel.call(market: fresh)
      end

      expect(results.count(&:success?)).to eq(1)
      expect(results.find(&:failure?).error).to eq("This market has already been settled")
      expect(market.reload).to be_settled
      expect_credits_conserved(market)
      expect_ledger_to_match_balances
    end
  end

  it "settles two markets that share bettors in parallel without deadlocking" do
    markets = create_list(:market, 2)
    bettors = create_list(:user, 4)
    markets.each do |market|
      bettors.first(2).each { |user| place_bet(user:, market:, outcome: "Lands it", stake: 40) }
      bettors.last(2).each { |user| place_bet(user:, market:, outcome: "Bails", stake: 60) }
      lock_now(market)
    end

    results = in_parallel(2) do |index|
      fresh = Market.find(markets[index].id)
      Markets::Resolve.call(market: fresh, winning_outcome_id: fresh.outcomes.find_by!(label: "Lands it").id)
    end

    expect(results).to all(be_success)
    markets.each { |market| expect_credits_conserved(market) }
    expect_ledger_to_match_balances
  end
end
