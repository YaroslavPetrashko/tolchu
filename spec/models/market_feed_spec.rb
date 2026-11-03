require "rails_helper"

RSpec.describe MarketFeed do
  let(:viewer) { create(:user) }

  it "lists open markets (closing soonest first), then markets awaiting results, then recent results" do
    later = create(:market, locks_at: 2.hours.from_now)
    sooner = create(:market, locks_at: 5.minutes.from_now)
    locked = create(:market, :locked)
    expired = create(:market, :expired)
    resolved = create(:market, :locked)
    Markets::Resolve.call(market: resolved, winning_outcome_id: resolved.outcomes.first.id)
    cancelled = create(:market)
    Markets::Cancel.call(market: cancelled)

    markets = described_class.new(viewer:).markets

    expect(markets.first(2)).to eq([ sooner, later ])
    expect(markets[2, 2]).to contain_exactly(locked, expired)
    expect(markets.last).to eq(resolved)
    expect(markets).not_to include(cancelled)
  end

  it "only shows the most recent results" do
    stub_const("MarketFeed::RECENT_RESULTS_LIMIT", 1)
    2.times do
      market = create(:market, :locked)
      Markets::Resolve.call(market:, winning_outcome_id: market.outcomes.first.id)
    end

    expect(described_class.new.markets.size).to eq(1)
  end

  it "looks up the viewer's bet on each market" do
    market = create(:market)
    other = create(:market)
    bet = place_bet(user: viewer, market:, outcome: "Lands it", stake: 10)

    feed = described_class.new(viewer:)

    expect(feed.bet_for(market)).to eq(bet)
    expect(feed.bet_for(other)).to be_nil
  end

  it "has no bets for a signed-out viewer" do
    market = create(:market)
    expect(described_class.new.bet_for(market)).to be_nil
  end
end
