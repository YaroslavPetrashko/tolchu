require "rails_helper"

RSpec.describe "Sealed market controls" do
  let(:creator) { create(:user) }
  let!(:market) { create(:market, creator:, sealed_answer_label: "Lands it") }

  before { sign_in_as creator }

  it "explains automatic settlement without asking the creator to declare another result" do
    get studio_markets_path

    expect(response.body).to include("The sealed result settles automatically when betting closes.")
    expect(response.body).not_to include("Declare result")
  end

  it "does not offer a replacement result while a locked sealed market waits for a retry" do
    Markets::Lock.call(market:)
    allow(Markets::SettleSealed).to receive(:call)

    get studio_markets_path

    expect(response.body).to include("The sealed result settles automatically when betting closes.", "Cancel market")
    expect(response.body).not_to include("Declare result", "What happened?")
  end

  it "explains early locking and settles the sealed answer on the redirected Studio page" do
    patch lock_studio_market_path(market)

    expect(flash[:notice]).to eq("Betting is locked on “#{market.question}”. The sealed result will settle automatically.")
    expect(market.reload).to be_locked

    follow_redirect!

    expect(market.reload).to have_attributes(status: "resolved", winning_outcome: market.sealed_winner)
    expect(response.body).not_to include("Declare result")
  end
end
