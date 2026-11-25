require "rails_helper"

RSpec.describe "Bet form bounds" do
  let(:market) { create(:market) }

  def bet_form
    Nokogiri::HTML5(response.body).at_css("#market_#{market.id} form.bet-pad--live")
  end

  [ [ 0, 0, 0 ], [ 3, 3, 3 ], [ 1_000, 100, Bet::DEFAULT_STAKE ] ].each do |balance, maximum, stake|
    it "renders an affordable default and native bounds with #{balance} credits" do
      sign_in_as create(:user, balance:)

      get market_path(market)

      expect(bet_form["data-bet-pad-max-value"]).to eq(maximum.to_s)
      expect(bet_form["data-bet-pad-refundable-stake-value"]).to eq("0")
      input = bet_form.at_css('input[name="stake"]')
      expect(input.attributes.slice("min", "max", "step", "value").transform_values(&:value))
        .to eq("min" => "1", "max" => maximum.to_s, "step" => "1", "value" => stake.to_s)
      expect(bet_form.at_css("button.bet-pad__button").key?("disabled")).to eq(balance.zero?)
      expect(bet_form.at_css('input[type="submit"]').key?("disabled")).to eq(balance.zero?)
    end
  end

  [ [ 20, 20, 20 ], [ 30, 20, 30 ], [ 200, 100, 100 ] ].each do |balance, original_stake, maximum|
    it "lets an edit reuse #{original_stake} staked credits within the #{maximum} credit budget" do
      fan = create(:user, balance:)
      place_bet(user: fan, market:, outcome: "Lands it", stake: original_stake)
      sign_in_as fan

      get market_path(market)

      expect(bet_form["data-bet-pad-refundable-stake-value"]).to eq(original_stake.to_s)
      expect(bet_form["data-bet-pad-max-value"]).to eq(maximum.to_s)
      expect(bet_form.at_css('input[name="stake"]')["max"]).to eq(maximum.to_s)
      expect(bet_form.at_css('input[name="stake"]')["value"]).to eq(original_stake.to_s)
      expect(bet_form.at_css("button.bet-pad__button").key?("disabled")).to be(false)
    end
  end
end
