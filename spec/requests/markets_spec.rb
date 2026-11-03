require "rails_helper"

RSpec.describe "Markets" do
  let(:creator) { create(:user, username: "StuntLab") }
  let!(:market) { create(:market, creator:, question: "Will he land the kickflip?", outcome_labels: [ "Lands it", "Bails" ]) }

  describe "GET / (the feed)" do
    it "shows open markets with their outcomes and pool to guests" do
      place_bet(user: create(:user), market:, outcome: "Lands it", stake: 60)
      place_bet(user: create(:user), market:, outcome: "Bails", stake: 40)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Will he land the kickflip?", "@StuntLab asks", "Lands it", "Bails")
      expect(response.body).to include("100 credits</strong> in the pool", "2 predictions", "60%", "40%")
      expect(response.body).to include("Sign in to predict")
      expect(response.body).not_to include("Place bet")
    end

    it "shows a bet form to signed-in fans" do
      sign_in_as create(:user)
      get root_path

      expect(response.body).to include("Place bet", %(name="outcome_id"), %(name="stake"), %(value="feed"))
    end

    it "shows the fan's existing prediction instead of the form" do
      fan = create(:user)
      place_bet(user: fan, market:, outcome: "Bails", stake: 20)
      sign_in_as fan

      get root_path

      expect(response.body).to include("You picked <strong>Bails</strong> for 20 credits")
      expect(response.body).not_to include("Place bet")
    end

    it "tells creators they can't bet on their own market" do
      sign_in_as creator
      get root_path

      expect(response.body).to include("You created this market, so you can't bet on it.")
    end

    it "shows locked and settled markets with their state" do
      Markets::Lock.call(market:)
      settled = create(:market, question: "Penalty: left or right?", outcome_labels: %w[Left Right])
      Markets::Lock.call(market: settled)
      Markets::Resolve.call(market: settled, winning_outcome_id: settled.outcomes.first.id)

      get root_path

      expect(response.body).to include("Betting closed. Waiting for the result", "Result: <strong>Left</strong>")
      expect(response.body).to include(%(badge--locked), %(badge--resolved))
    end

    it "invites people to post when the feed is empty" do
      Markets::Cancel.call(market:)
      get root_path

      expect(response.body).to include("No clips yet")
    end
  end

  describe "GET /markets/:id" do
    it "shows the clip, the pool breakdown, and when betting closes" do
      get market_path(market)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pool breakdown", "Will he land the kickflip?", "Betting closes")
      expect(response.body).to include(%(value="page")).or include("Sign in to predict")
    end

    it "shows the settlement once resolved" do
      place_bet(user: create(:user), market:, outcome: "Lands it", stake: 100)
      place_bet(user: create(:user), market:, outcome: "Bails", stake: 100)
      Markets::Lock.call(market:)
      Markets::Resolve.call(market:, winning_outcome_id: outcome(market, "Lands it").id)

      get market_path(market)

      expect(response.body).to include("Settlement", "House fee", "Creator reward", "100%")
    end

    it "explains a cancelled market" do
      Markets::Cancel.call(market:)
      get market_path(market)

      expect(response.body).to include("This market was cancelled and every stake was refunded.")
    end

    it "returns 404 for an unknown market" do
      get market_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end
end
