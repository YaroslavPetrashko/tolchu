require "rails_helper"

RSpec.describe "Bets" do
  let(:market) { create(:market, question: "Will he land the kickflip?", outcome_labels: [ "Lands it", "Bails" ]) }
  let(:fan) { create(:user, balance: 1_000) }
  let(:lands_it) { outcome(market, "Lands it") }

  def place(stake: 50, outcome_id: lands_it.id, context: "feed", format: :html)
    headers = format == :turbo_stream ? { "Accept" => "text/vnd.turbo-stream.html, text/html" } : {}
    post market_bets_path(market), params: { outcome_id:, stake:, context: }, headers:
  end

  it "requires a signed-in user" do
    place
    expect(response).to redirect_to(new_session_path)
    expect(Bet.count).to eq(0)
  end

  context "when signed in" do
    before { sign_in_as fan }

    it "places the bet and returns to the card on the feed" do
      place

      expect(response).to redirect_to(root_path(anchor: "market_#{market.id}"))
      expect(flash.keys).not_to include("bet_error")
      expect(fan.reload.balance).to eq(950)
    end

    it "returns to the market page when placed from there" do
      place(context: "page")
      expect(response).to redirect_to(market_path(market))
    end

    it "redirects back with the reason when the bet is rejected" do
      place(stake: 500)

      expect(response).to redirect_to(root_path(anchor: "market_#{market.id}"))
      expect(flash[:bet_error]).to eq("Stake must be less than or equal to 100")
      expect(flash[:bet_error_market_id]).to eq(market.id)
      expect(fan.reload.balance).to eq(1_000)
    end

    it "treats a non-numeric stake as invalid" do
      place(stake: "lots")
      expect(flash[:bet_error]).to eq("Stake is not a number")
    end

    it "updates the card, balance, and session bar in place over Turbo Streams" do
      place(format: :turbo_stream)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(<turbo-stream action="replace" target="market_#{market.id}">))
      wallet = Nokogiri::HTML5.fragment(response.body).at_css('turbo-stream[action="replace"][target="wallet-balance"] template #wallet-balance')
      expect(wallet.text).to eq("950")
      expect(wallet["data-wallet-balance-amount-value"]).to eq("950")
      expect(response.body).to include(%(<turbo-stream action="replace" target="session-strip">), %(class="session-tile session-tile--pending"))
      expect(response.body).to include(%(title="Lands it">Lands it</button>))
      expect(response.body).not_to include(%(target="flash"))
    end

    it "shows the error over Turbo Streams when rejected" do
      travel_to(market.locks_at + 1.second) { place(format: :turbo_stream) }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(%(<turbo-stream action="replace" target="bet_hint_market_#{market.id}">),
                                       "bet-pad__hint--error", "Betting is closed for this market")
    end

    describe "changing a bet before the lock" do
      let!(:bet) { place_bet(user: fan, market:, outcome: "Lands it", stake: 50) }

      def change(outcome_id: outcome(market, "Bails").id, stake: 30, bet_id: bet.id)
        patch market_bet_path(market, bet_id), params: { outcome_id:, stake:, context: "feed" },
                                               headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
      end

      it "swaps the pick and stake and redraws the card" do
        change

        expect(bet.reload).to have_attributes(outcome: outcome(market, "Bails"), stake: 30)
        expect(fan.reload.balance).to eq(970)
        expect(response.body).to include(%(title="Bails">Bails</button>))
      end

      it "refuses once betting has closed" do
        travel_to(market.locks_at + 1.second) { change }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(bet.reload.stake).to eq(50)
      end

      context "when all available credits were staked" do
        let(:fan) { create(:user, balance: 50) }

        it "publishes the released credits and matching edit bounds together" do
          change(stake: 30)

          fragment = Nokogiri::HTML5.fragment(response.body)
          wallet = fragment.at_css('turbo-stream[target="wallet-balance"] #wallet-balance')
          form = fragment.at_css("form.bet-pad--live")
          expect(wallet["data-wallet-balance-amount-value"]).to eq("20")
          expect(form["data-bet-pad-max-value"]).to eq("50")
          expect(form.at_css('input[name="stake"]')["max"]).to eq("50")
          expect(fan.reload.balance).to eq(20)
        end
      end

      it "can't touch someone else's bet" do
        other = place_bet(user: create(:user), market:, outcome: "Bails", stake: 10)
        change(bet_id: other.id)

        expect(response).to have_http_status(:not_found)
        expect(other.reload.stake).to eq(10)
      end
    end

    it "returns 404 for an unknown market" do
      post market_bets_path(market_id: 0), params: { outcome_id: 1, stake: 10 }
      expect(response).to have_http_status(:not_found)
    end
  end

  context "rate limiting" do
    let(:limiter_store) { ActiveSupport::Cache::MemoryStore.new }
    let(:too_fast) { "You're placing bets too fast. Wait a minute and try again." }

    # The test cache is a null store, so counters never add up; send them to a real one.
    before do
      allow(Rails.cache).to receive(:increment) { |*args, **options| limiter_store.increment(*args, **options) }
      sign_in_as fan
      20.times { place }
    end

    it "redirects the 21st bet in a minute back with an alert and doesn't run it" do
      expect(Betting::PlaceBet).not_to receive(:call)

      place

      expect(response).to redirect_to(root_path(anchor: "market_#{market.id}"))
      expect(flash[:alert]).to eq(too_fast)
    end

    it "answers a Turbo request with 429 and the message in the flash area" do
      expect(Betting::PlaceBet).not_to receive(:call)

      place(format: :turbo_stream)

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include('target="flash"').and include("placing bets too fast")
    end

    it "doesn't slow down another user" do
      delete session_path
      other = create(:user)
      sign_in_as other

      place

      expect(flash[:alert]).to be_nil
      expect(other.bets.count).to eq(1)
    end

    it "lets the same user bet again after the minute passes" do
      other_market = create(:market)
      travel 61.seconds

      expect { post market_bets_path(other_market), params: { outcome_id: other_market.outcomes.first.id, stake: 10 } }
        .to change { fan.bets.count }.by(1)
    end
  end
end
