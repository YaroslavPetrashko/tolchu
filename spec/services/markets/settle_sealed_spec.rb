require "rails_helper"

RSpec.describe Markets::SettleSealed do
  def sealed_market(answer: "Lands it", **attributes)
    create(:market, sealed_answer_label: answer, **attributes)
  end

  it "settles a sealed market on its answer once betting has closed" do
    market = sealed_market
    winner = create(:user)
    place_bet(user: winner, market:, outcome: "Lands it", stake: 50)
    place_bet(user: create(:user), market:, outcome: "Bails", stake: 50)

    travel_to(market.locks_at + 1.second) { expect(described_class.call.value).to eq(1) }

    expect(market.reload).to have_attributes(status: "resolved", winning_outcome: outcome(market, "Lands it"))
    expect(winner.bets.sole).to have_attributes(status: "won", payout: 95)
  end

  it "leaves markets that are still open, unsealed, or already settled alone" do
    open_market = sealed_market(locks_at: 1.hour.from_now)
    unsealed = create(:market, :locked)
    settled = sealed_market
    travel_to(settled.locks_at + 1.second) { described_class.call }

    expect(described_class.call.value).to eq(0)
    expect(open_market.reload).to be_open
    expect(unsealed.reload).to be_locked
    expect(settled.reload.resolved_at).to be_present
  end

  it "can be limited to one market" do
    first = sealed_market
    second = sealed_market

    travel_to(first.locks_at + 1.second) do
      expect(described_class.call(scope: Market.where(id: first.id)).value).to eq(1)
    end
    expect(second.reload).not_to be_resolved
  end

  context "when one market cannot be settled" do
    let!(:broken) { sealed_market }
    let!(:healthy) { sealed_market }

    before do
      allow(Markets::Resolve).to receive(:call).and_call_original
      allow(Markets::Resolve).to receive(:call).with(hash_including(market: broken))
                                               .and_raise(ActiveRecord::Deadlocked, "deadlock detected")
    end

    it "still settles the others and does not raise" do
      result = travel_to(healthy.locks_at + 1.second) { described_class.call }

      expect(result).to be_success
      expect(result.value).to eq(1)
      expect(healthy.reload).to be_resolved
      expect(broken.reload).not_to be_resolved
    end

    it "logs the failure with the market id and reports it" do
      allow(Rails.logger).to receive(:error)
      allow(Rails.error).to receive(:report)

      travel_to(healthy.locks_at + 1.second) { described_class.call }

      expect(Rails.logger).to have_received(:error).with(/market #{broken.id} could not be settled: ActiveRecord::Deadlocked/)
      expect(Rails.error).to have_received(:report)
        .with(an_instance_of(ActiveRecord::Deadlocked), handled: true, context: { market_id: broken.id })
    end

    it "tries the market again on the next call" do
      travel_to(healthy.locks_at + 1.second) { described_class.call }
      allow(Markets::Resolve).to receive(:call).and_call_original

      travel_to(healthy.locks_at + 2.seconds) { expect(described_class.call.value).to eq(1) }
      expect(broken.reload).to be_resolved
    end
  end

  context "when a market hits a passing database clash" do
    let!(:market) { sealed_market }

    def fail_first(times, error)
      calls = 0
      allow(Markets::Resolve).to receive(:call).and_wrap_original do |original, **arguments|
        calls += 1
        raise error if calls <= times

        original.call(**arguments)
      end
    end

    it "tries again straight away and settles without logging an error" do
      fail_first(2, ActiveRecord::Deadlocked)
      allow(Rails.logger).to receive(:error)

      travel_to(market.locks_at + 1.second) { expect(described_class.call.value).to eq(1) }

      expect(market.reload).to be_resolved
      expect(Rails.logger).not_to have_received(:error)
    end

    it "gives up after three attempts and leaves it for the next page load" do
      fail_first(3, ActiveRecord::LockWaitTimeout)

      travel_to(market.locks_at + 1.second) { expect(described_class.call.value).to eq(0) }

      expect(Markets::Resolve).to have_received(:call).exactly(3).times
      expect(market.reload).not_to be_resolved
    end

    it "does not retry an error that would only fail the same way again" do
      fail_first(1, ActiveRecord::RecordInvalid)

      travel_to(market.locks_at + 1.second) { expect(described_class.call.value).to eq(0) }

      expect(Markets::Resolve).to have_received(:call).once
    end
  end

  context "when nothing is due" do
    it "runs one existence query and settles nothing" do
      sealed_market(locks_at: 1.hour.from_now)
      allow(Markets::Resolve).to receive(:call)
      queries = []
      counter = ->(*, payload) { queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        expect(described_class.call.value).to eq(0)
      end

      expect(queries.size).to eq(1)
      expect(queries.first).to match(/\ASELECT 1 AS one/)
      expect(Markets::Resolve).not_to have_received(:call)
    end
  end
end
