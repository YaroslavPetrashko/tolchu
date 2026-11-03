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
      expect(flash[:notice]).to eq("Prediction locked in: Lands it for 50 credits.")
      expect(fan.reload.balance).to eq(950)
    end

    it "returns to the market page when placed from there" do
      place(context: "page")
      expect(response).to redirect_to(market_path(market))
    end

    it "redirects back with the reason when the bet is rejected" do
      place(stake: 500)

      expect(response).to redirect_to(root_path(anchor: "market_#{market.id}"))
      expect(flash[:alert]).to eq("Stake must be less than or equal to 100")
      expect(fan.reload.balance).to eq(1_000)
    end

    it "treats a non-numeric stake as invalid" do
      place(stake: "lots")
      expect(flash[:alert]).to eq("Stake is not a number")
    end

    it "updates the card, balance, and flash in place over Turbo Streams" do
      place(format: :turbo_stream)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(<turbo-stream action="replace" target="market_#{market.id}">))
      expect(response.body).to include(%(<turbo-stream action="update" target="wallet-balance"><template>950</template>))
      expect(response.body).to include("You picked <strong>Lands it</strong> for 50 credits")
      expect(response.body).to include("Prediction locked in: Lands it for 50 credits.")
    end

    it "shows the error over Turbo Streams when rejected" do
      travel_to(market.locks_at + 1.second) { place(format: :turbo_stream) }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(%(<turbo-stream action="update" target="flash">), "Betting is closed for this market")
    end

    it "returns 404 for an unknown market" do
      post market_bets_path(market_id: 0), params: { outcome_id: 1, stake: 10 }
      expect(response).to have_http_status(:not_found)
    end
  end
end
