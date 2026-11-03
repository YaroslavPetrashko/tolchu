require "rails_helper"

RSpec.describe "Registrations" do
  let(:valid_params) do
    { user: { username: "rookie", email_address: "rookie@example.com", password: "password123", password_confirmation: "password123" } }
  end

  describe "GET /registration/new" do
    it "renders the sign up form" do
      get new_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Join Tolchu", "1,000 credits")
    end

    it "is also reachable at /sign_up" do
      get "/sign_up"
      expect(response).to have_http_status(:ok)
    end

    it "sends signed-in users to the feed" do
      sign_in_as create(:user)
      get new_registration_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /registration" do
    it "creates the account, grants starting credits, and signs the user in" do
      expect { post registration_path, params: valid_params }.to change(User, :count).by(1)

      user = User.find_by!(username: "rookie")
      expect(user.balance).to eq(1_000)
      expect(response).to redirect_to(root_url)
      follow_redirect!
      expect(response.body).to include("Welcome to Tolchu, rookie!")
      expect(response.body).to include(%(id="wallet-balance">1,000))
    end

    it "re-renders the form with errors when the details are invalid" do
      params = valid_params.deep_merge(user: { password_confirmation: "different" })

      expect { post registration_path, params: }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Password confirmation doesn&#39;t match Password")
    end

    it "rejects a taken username regardless of case" do
      create(:user, username: "Rookie")
      post registration_path, params: valid_params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Username has already been taken")
    end
  end
end
