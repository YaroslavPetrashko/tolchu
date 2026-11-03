require "rails_helper"

RSpec.describe ApplicationHelper do
  describe "#credits" do
    it "formats amounts with delimiters and the right noun" do
      expect(helper.credits(1)).to eq("1 credit")
      expect(helper.credits(0)).to eq("0 credits")
      expect(helper.credits(1_250)).to eq("1,250 credits")
    end
  end

  describe "#signed_credits" do
    it "prefixes gains and losses" do
      expect(helper.signed_credits(126)).to eq("+126")
      expect(helper.signed_credits(-1_500)).to eq("−1,500")
      expect(helper.signed_credits(0)).to eq("0")
    end
  end

  describe "#multiplier" do
    it "shows payout multiples with two decimals" do
      expect(helper.multiplier(Rational(19, 10))).to eq("×1.90")
      expect(helper.multiplier(nil)).to eq("—")
    end
  end

  describe "#percent" do
    it "rounds to a whole percentage" do
      expect(helper.percent(0.666)).to eq("67%")
      expect(helper.percent(0)).to eq("0%")
    end
  end

  describe "phase helpers" do
    let(:market) { create(:market, locks_at: 10.minutes.from_now) }

    it "labels each phase" do
      expect(helper.phase_label(market)).to eq("Live")
      expect(helper.phase_badge(market)).to eq(%(<span class="badge badge--open">Live</span>))
    end

    it "describes the lock status for each phase" do
      expect(helper.lock_status_text(market)).to eq("Locks in 10 minutes")
      expect(helper.lock_status_text(market, now: market.locks_at)).to eq("Betting closed. Waiting for the result")
      market.status = "resolved"
      expect(helper.lock_status_text(market)).to eq("Result is in")
      market.status = "cancelled"
      expect(helper.lock_status_text(market)).to eq("Cancelled. Stakes refunded")
    end
  end

  describe "#bet_status_label" do
    let(:bet) { build(:bet, stake: 50) }

    it "describes each bet outcome" do
      expect(helper.bet_status_label(bet)).to eq("Pending")
      bet.assign_attributes(status: :won, payout: 95)
      expect(helper.bet_status_label(bet)).to eq("Won +45")
      bet.assign_attributes(status: :lost, payout: 0)
      expect(helper.bet_status_label(bet)).to eq("Lost −50")
      bet.assign_attributes(status: :refunded, payout: 50)
      expect(helper.bet_status_label(bet)).to eq("Refunded")
    end
  end
end
