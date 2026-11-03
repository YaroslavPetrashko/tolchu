require "rails_helper"

RSpec.describe "Sessions" do
  let!(:user) { create(:user, username: "regular", email_address: "regular@example.com") }

  describe "GET /session/new" do
    it "renders the sign in form" do
      get new_session_path
      expect(response.body).to include("Welcome back")
    end

    it "sends signed-in users to the feed" do
      sign_in_as user
      get new_session_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /session" do
    it "signs in with the right password" do
      post session_path, params: { email_address: "Regular@Example.com", password: "password123" }

      expect(response).to redirect_to(root_url)
      expect(flash[:notice]).to eq("Welcome back, regular!")
      expect(user.sessions.count).to eq(1)
      expect(cookies[:session_id]).to be_present
    end

    it "refuses the wrong password" do
      post session_path, params: { email_address: user.email_address, password: "wrong-password" }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("That email and password don't match.")
      expect(user.sessions).to be_empty
    end

    it "returns users to the page they originally asked for" do
      get wallet_path
      expect(response).to redirect_to(new_session_path)

      post session_path, params: { email_address: user.email_address, password: "password123" }
      expect(response).to redirect_to(wallet_url)
    end

    it "doesn't try to return users to a form submission" do
      market = create(:market)
      post market_bets_path(market), params: { outcome_id: market.outcomes.first.id, stake: 10 }
      expect(response).to redirect_to(new_session_path)

      post session_path, params: { email_address: user.email_address, password: "password123" }
      expect(response).to redirect_to(root_url)
    end
  end

  describe "DELETE /session" do
    it "signs the user out" do
      sign_in_as user
      delete session_path

      expect(response).to redirect_to(root_path)
      expect(user.sessions).to be_empty
      follow_redirect!
      expect(response.body).to include("Sign in")
    end
  end
end
