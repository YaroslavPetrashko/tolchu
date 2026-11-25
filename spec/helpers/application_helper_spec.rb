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

  describe "#bet_multiplier" do
    let(:market) { create(:market) }
    # Loaded fresh, the way a page loads it, so the pools include both bets.
    let(:bet) { Bet.find(@bet_id) }

    before do
      @bet_id = place_bet(user: create(:user), market:, outcome: "Lands it", stake: 40).id
      place_bet(user: create(:user), market:, outcome: "Bails", stake: 60)
    end

    it "shows what a pending bet would pay per credit right now" do
      expect(helper.bet_multiplier(bet)).to eq(Rational(95, 40))
      expect(helper.multiplier(helper.bet_multiplier(bet))).to eq("×2.38")
    end

    it "shows what a won bet actually paid per credit" do
      bet.assign_attributes(status: :won, payout: 95)
      expect(helper.bet_multiplier(bet)).to eq(Rational(95, 40))
    end

    it "shows ×1.00 for a refunded bet, which gets exactly its stake back" do
      bet.assign_attributes(status: :refunded, payout: 40)
      expect(helper.multiplier(helper.bet_multiplier(bet))).to eq("×1.00")
    end
  end

  describe "bet pad helpers" do
    it "maps outcomes to flick directions by count" do
      expect(helper.pad_directions(2)).to eq(%w[l r])
      expect(helper.pad_directions(3)).to eq(%w[u l r])
      expect(helper.pad_directions(4)).to eq(%w[ul ur dl dr])
    end

    it "projects what a stake would pay back, rounded down" do
      market = create(:market)
      place_bet(user: create(:user), market:, outcome: "Lands it", stake: 70)
      place_bet(user: create(:user), market:, outcome: "Bails", stake: 30)

      expect(helper.projected_payout(market.reload, market.outcomes.find_by!(label: "Bails"), 10)).to eq(26)
    end

    it "measures how much of the betting window is left" do
      market = build(:market, created_at: Time.zone.local(2026, 11, 19, 12, 0, 0), locks_at: Time.zone.local(2026, 11, 19, 12, 10, 0))

      expect(helper.lock_progress(market, now: market.created_at)).to eq(1.0)
      expect(helper.lock_progress(market, now: market.created_at + 150.seconds)).to eq(0.75)
      expect(helper.lock_progress(market, now: market.locks_at + 1.second)).to eq(0.0)
      expect(helper.lock_progress(build(:market, created_at: market.locks_at, locks_at: market.locks_at))).to eq(0.0)
    end

    it "shows the time left before the lock as a clock" do
      market = build(:market, locks_at: Time.zone.local(2026, 11, 19, 12, 0, 0))

      expect(helper.lock_clock(market, now: market.locks_at - 161.seconds)).to eq("2:41")
      expect(helper.lock_clock(market, now: market.locks_at - 3_725.seconds)).to eq("1:02:05")
      expect(helper.lock_clock(market, now: market.locks_at)).to be_nil
    end
  end
end
