require "rails_helper"

RSpec.describe "Wallet updates in card responses" do
  let(:fan) { create(:user) }
  let!(:market) { create(:market, sealed_answer_label: "Lands it") }

  def wallet_in_stream
    Nokogiri::HTML5.fragment(response.body).at_css('turbo-stream[action="replace"][target="wallet-balance"] template #wallet-balance')
  end

  before do
    sign_in_as fan
    place_bet(user: fan, market:, outcome: "Lands it", stake: 20)
  end

  it "includes the new balance after a sealed win without a full-page navigation" do
    place_bet(user: create(:user), market:, outcome: "Bails", stake: 20)

    travel_to(market.locks_at + 1.second) { get card_market_path(market, context: "feed") }

    expect(wallet_in_stream.text).to eq("1,018")
    expect(wallet_in_stream["data-wallet-balance-amount-value"]).to eq("1018")
    expect(fan.reload.balance).to eq(1_018)
  end

  it "includes refunded credits when a sealed market has no contest" do
    travel_to(market.locks_at + 1.second) { get card_market_path(market, context: "feed") }

    expect(wallet_in_stream.text).to eq("1,000")
    expect(wallet_in_stream["data-wallet-balance-amount-value"]).to eq("1000")
    expect(fan.reload.balance).to eq(1_000)
  end

  it "does not send a user's wallet to a guest" do
    delete session_path

    travel_to(market.locks_at + 1.second) { get card_market_path(market, context: "feed") }

    expect(response).to have_http_status(:ok)
    expect(wallet_in_stream).to be_nil
  end

  it "renders open-card stake bounds from a freshly reloaded balance" do
    fan.update!(balance: 3)

    get card_market_path(create(:market), context: "feed")

    expect(wallet_in_stream["data-wallet-balance-amount-value"]).to eq("3")
    form = Nokogiri::HTML5.fragment(response.body).at_css("form.bet-pad--live")
    expect(form["data-bet-pad-max-value"]).to eq("3")
  end
end
