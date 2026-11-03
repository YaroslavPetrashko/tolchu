require "rails_helper"

RSpec.describe "Wallet" do
  it "requires a signed-in user" do
    get wallet_path
    expect(response).to redirect_to(new_session_path)
  end

  context "when signed in" do
    let(:fan) { User.register(username: "fan", email_address: "fan@example.com", password: "password123") }
    let(:market) { create(:market, question: "Will the free throw go in?", outcome_labels: %w[Swish Brick]) }
    let(:other_market) { create(:market, question: "Will he land the kickflip?") }

    before { sign_in_as fan }

    it "shows the balance, predictions, results, and every credit movement" do
      place_bet(user: fan, market:, outcome: "Swish", stake: 100)
      place_bet(user: create(:user), market:, outcome: "Brick", stake: 100)
      place_bet(user: fan, market: other_market, outcome: "Bails", stake: 40)
      Markets::Lock.call(market:)
      Markets::Resolve.call(market:, winning_outcome_id: outcome(market, "Swish").id)

      get wallet_path

      expect(response.body).to include(%(<p class="wallet-hero__balance">1,050 <span class="wallet-hero__unit">credits</span>))
      expect(response.body).to include("Won +90", "Pending")
      expect(response.body).to include("Welcome bonus", "Prediction on “Will the free throw go in?”", "Won “Will the free throw go in?”")
      expect(response.body).to include("−100", "+190", "+1,000")
    end

    it "shows lost and refunded predictions" do
      place_bet(user: fan, market:, outcome: "Swish", stake: 30)
      place_bet(user: create(:user), market:, outcome: "Brick", stake: 30)
      place_bet(user: fan, market: other_market, outcome: "Bails", stake: 20)
      Markets::Lock.call(market:)
      Markets::Resolve.call(market:, winning_outcome_id: outcome(market, "Brick").id)
      Markets::Cancel.call(market: other_market)

      get wallet_path

      expect(response.body).to include("Lost −30", "Refunded", "Refund for “Will he land the kickflip?”")
    end

    it "nudges new users toward the feed" do
      get wallet_path
      expect(response.body).to include("No predictions yet.")
    end
  end
end
