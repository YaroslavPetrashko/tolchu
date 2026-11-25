module PadRecoveryWorld
  def recovery_pad(question)
    card_for(question).find("form.bet-pad--live")
  end

  def recovery_stake(question)
    recovery_pad(question).find('input[name="stake"]', visible: :all)
  end

  def prediction_request_count(question)
    path = market_bets_path(market_named(question))
    evaluate_script("window.padRecoveryRequests[#{path.to_json}] || 0")
  end
end

World(PadRecoveryWorld)

When("I open the recovery feed") do
  visit root_path
  expect(page).to have_css("form.bet-pad.is-enhanced")
  execute_script(<<~'JS')
    window.tolchuSamePage = true;
    window.padRecoveryRequests = {};
    document.addEventListener("turbo:before-fetch-request", (event) => {
      if (!event.target.matches("form.bet-pad")) return;
      const path = new URL(event.target.action).pathname.replace(/\/\d+$/, "");
      window.padRecoveryRequests[path] = (window.padRecoveryRequests[path] || 0) + 1;
    });
  JS
end

When("I type stake {string} into the pad for {string}") do |value, question|
  input = recovery_stake(question)
  input.send_keys([ :control, "a" ], :backspace)
  input.send_keys(value) unless value.empty?
end

When("I try to raise the invalid stake on {string}") do |question|
  recovery_pad(question).find("button.bet-pad__button").send_keys(:arrow_up)
end

When("I try to raise the stake above the budget on {string}") do |question|
  recovery_pad(question).find("button.bet-pad__button").send_keys(:arrow_up)
end

When("I open my prediction editor for {string}") do |question|
  card_for(question).find('button[aria-label="Change your bet"]').click
  expect(card_for(question)).to have_css("form.bet-pad--live", visible: true)
end

When("the next prediction request for {string} loses its connection") do |question|
  execute_script(<<~JS, market_bets_path(market_named(question)))
    const path = arguments[0];
    const originalFetch = window.fetch.bind(window);
    let failed = false;
    window.fetch = (input, options) => {
      const url = input instanceof Request ? input.url : input;
      if (!failed && new URL(url, location.href).pathname === path) {
        failed = true;
        document.documentElement.dataset.padRecoveryFailure = "true";
        return Promise.reject(new TypeError("Simulated lost connection"));
      }
      return originalFetch(input, options);
    };
  JS
end

Then("the pad for {string} should recover from the failed request") do |question|
  expect(page).to have_css('html[data-pad-recovery-failure="true"]', visible: :all)
  expect(recovery_pad(question)).not_to match_css(".is-waiting")
  expect(recovery_pad(question)).to have_css("button.bet-pad__button:not([disabled])")
  expect(current_user.bets.where(market: market_named(question))).not_to exist
end

Then("the pad for {string} should allow at most {int} credits with stake {string}") do |question, maximum, stake|
  expect(recovery_pad(question)).to have_css(%(input[name="stake"][min="1"][max="#{maximum}"][step="1"]), visible: :all)
  expect(recovery_stake(question).value).to eq(stake)
  expect(recovery_pad(question)).to have_css(".bet-pad__stake", exact_text: stake)
end

Then("the pad for {string} should be disabled without sending a prediction") do |question|
  pad = recovery_pad(question)
  expect(pad).to have_css("button.bet-pad__button[disabled]")
  expect(pad).to have_css('input[type="submit"][disabled]', visible: :all)
  expect(recovery_stake(question).evaluate_script("this.checkValidity()")).to be(false)
  expect(prediction_request_count(question)).to eq(0)
  expect(current_user.bets.where(market: market_named(question))).not_to exist
end

Then("the pad for {string} should keep invalid stake {string} and remain usable") do |question, stake|
  expect(recovery_stake(question).value).to eq(stake)
  expect(recovery_stake(question).evaluate_script("this.checkValidity()")).to be(false)
  expect(recovery_pad(question)).not_to match_css(".is-waiting")
  expect(recovery_pad(question)).to have_css("button.bet-pad__button:not([disabled])")
  expect(prediction_request_count(question)).to eq(0)
  expect(current_user.bets.where(market: market_named(question))).not_to exist
end

Then("the pad for {string} should show finite odds or an unavailable estimate") do |question|
  expect(recovery_pad(question).text).not_to match(/NaN|Infinity/)
end

Then("exactly {int} prediction request(s) should have been sent for {string}") do |count, question|
  expect(prediction_request_count(question)).to eq(count)
end

Then("my predictions and wallet should still total {int} credits") do |total|
  expect(current_user.balance + current_user.bets.sum(:stake)).to eq(total)
end
