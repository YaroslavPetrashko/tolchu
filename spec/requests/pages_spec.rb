require "rails_helper"

RSpec.describe "Pages" do
  describe "GET /how-it-works" do
    it "explains the parimutuel model in plain English" do
      get how_it_works_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("The house never bets against you", "5% fee", "100 credits")
    end
  end

  describe "GET /up" do
    it "reports the app is healthy" do
      get rails_health_check_path
      expect(response).to have_http_status(:ok)
    end
  end
end
