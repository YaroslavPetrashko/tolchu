require "rails_helper"

RSpec.describe Markets::Lock do
  let(:market) { create(:market, locks_at: 30.minutes.from_now) }

  it "closes betting immediately and records when" do
    freeze_time do
      result = described_class.call(market:)

      expect(result).to be_success
      expect(market.reload).to be_locked
      expect(market.locked_at).to eq(Time.current)
      expect(market.locks_at).to eq(Time.current)
      expect(market.accepting_bets?).to be(false)
    end
  end

  it "refuses to lock a market whose betting already closed" do
    described_class.call(market:)

    expect(described_class.call(market:).error).to eq("Betting has already closed on this market")
  end

  it "refuses to lock a market past its deadline" do
    travel_to(market.locks_at + 1.second) do
      expect(described_class.call(market:)).to be_failure
      expect(market.reload).to be_open
    end
  end
end
