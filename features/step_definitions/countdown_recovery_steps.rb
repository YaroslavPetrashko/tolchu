module CountdownRecoveryHelpers
  def watch_countdown(question, failures: 0, unavailable: false, delay: 0, stalled: false)
    visit root_path
    card = card_for(question)
    expect(card).to have_css(".bet-pad--live.is-enhanced")
    execute_script(<<~JS, card["data-countdown-refresh-url-value"], failures, unavailable, delay, stalled)
      window.tolchuSamePage = true;
      const state = window.countdownRecovery = {
        requests: 0, submissions: 0, aborts: 0,
        failures: arguments[1], unavailable: arguments[2], delay: arguments[3], stalled: arguments[4]
      };
      const cardPath = new URL(arguments[0], location.href).pathname;
      const originalFetch = window.fetch.bind(window);
      document.addEventListener("submit", (event) => {
        if (event.target.matches("form.bet-pad--live")) state.submissions += 1;
      }, true);
      window.fetch = async (input, options) => {
        const url = input instanceof Request ? input.url : input;
        if (new URL(url, location.href).pathname !== cardPath) return originalFetch(input, options);
        state.requests += 1;
        document.documentElement.dataset.countdownRequests = state.requests;
        if (state.stalled) {
          return new Promise((resolve, reject) => {
            options.signal.addEventListener("abort", () => {
              state.aborts += 1;
              document.documentElement.dataset.countdownAborts = state.aborts;
              reject(new DOMException("Aborted", "AbortError"));
            }, { once: true });
          });
        }
        if (state.failures > 0) {
          state.failures -= 1;
          throw new TypeError("Simulated lost connection");
        }
        if (state.unavailable) return new Response("Unavailable", { status: 503 });
        const response = await originalFetch(input, options);
        if (state.delay) await new Promise((resolve) => setTimeout(resolve, state.delay));
        return response;
      };
    JS
  end

  def reconnect_countdown(question, **timestamps)
    execute_script(<<~JS, card_for(question), timestamps.transform_keys(&:to_s))
      const card = arguments[0];
      const replacement = card.cloneNode(true);
      for (const [name, value] of Object.entries(arguments[1])) replacement.setAttribute(name, value);
      card.replaceWith(replacement);
    JS
  end
end

World(CountdownRecoveryHelpers)

When("I watch the countdown for {string}") do |question|
  watch_countdown(question)
end

When("I watch {string} with slow card refresh replies") do |question|
  watch_countdown(question, delay: 2200)
end

When("I watch {string} with its first card refresh failing") do |question|
  watch_countdown(question, failures: 1)
end

When("I watch {string} while card refreshes are unavailable") do |question|
  watch_countdown(question, unavailable: true)
end

When("I watch {string} with a stalled card refresh") do |question|
  watch_countdown(question, stalled: true)
end

When("{string} expires before its countdown connects") do |question|
  market = market_named(question)
  market.update_columns(locks_at: 1.second.ago)
  # Deliver an open card after its deadline, rather than calling the controller's lock method.
  reconnect_countdown(question,
    "data-countdown-locks-at-value": market.locks_at.iso8601(3),
    "data-countdown-server-now-value": Time.current.iso8601(3))
  expect(card_for(question)).to have_css(".bet-pad--live button:disabled")
end

Then("the recovered countdown for {string} should show the locked card") do |question|
  expect(page).to have_css("article.clip-card--locked", text: question, wait: 12)
  expect(card_for(question)).to have_no_css("form.bet-pad--live")
  expect(card_for(question)).to have_css(".bet-pad__button--static", text: "Locked")
end

Then("the countdown should have requested the card {int} time(s)") do |count|
  expect(evaluate_script("window.countdownRecovery.requests")).to eq(count)
end

Then("{string} should offer a countdown retry after {int} attempts") do |question, count|
  within(card_for(question)) do
    expect(page).to have_css(".bet-pad__hint.is-visible", text: "Couldn't update this market.", wait: 10)
    expect(page).to have_button("Retry update", disabled: false)
  end
  expect(evaluate_script("window.countdownRecovery.requests")).to eq(count)
end

Then("the countdown should stop requesting the card") do
  before = evaluate_script("window.countdownRecovery.requests")
  sleep 2.2
  expect(evaluate_script("window.countdownRecovery.requests")).to eq(before)
end

When("card refreshes become available and I retry {string}") do |question|
  execute_script("window.countdownRecovery.unavailable = false")
  within(card_for(question)) { click_button "Retry update" }
end

When("I watch {string} with my device clock offset by {int} minutes") do |question, minutes|
  watch_countdown(question)
  execute_script(<<~JS, minutes)
    const originalNow = Date.now.bind(Date);
    const offset = arguments[0] * 60_000;
    Date.now = () => originalNow() + offset;
  JS
  reconnect_countdown(question)
end

Then("the countdown for {string} should still allow betting") do |question|
  expect(card_for(question)[:class].split).not_to include("is-locked")
  expect(card_for(question)).to have_css("button.bet-pad__button:enabled")
end

When("I background the countdown tab") do
  execute_script(<<~JS)
    Object.defineProperty(document, "hidden", { configurable: true, get: () => true });
    document.dispatchEvent(new Event("visibilitychange"));
  JS
end

When("{string} expires on the server while I am away") do |question|
  # The browser's monotonic clock has not advanced to this deadline, as after device sleep.
  market_named(question).update_columns(locks_at: 1.second.ago)
end

When("I resume the countdown tab") do
  execute_script(<<~JS)
    Object.defineProperty(document, "hidden", { configurable: true, get: () => false });
    document.dispatchEvent(new Event("visibilitychange"));
  JS
end

When("I leave the feed through Turbo navigation") do
  find("button[aria-label='Open menu']").click
  click_link "How it works"
  expect(page).to have_current_path(how_it_works_path)
end

When("I return to the cached feed") do
  page.go_back
  expect(page).to have_current_path(root_path)
end

When("I select {string} on {string} before countdown closure") do |outcome, question|
  card_for(question).find("li.bet-pad__section", text: outcome).find("input[type=radio]", visible: :all).send_keys(:space)
end

Then("every live betting control on {string} should be disabled") do |question|
  expect(card_for(question)).to have_no_css(".bet-pad--live :is(button, input, select, textarea):enabled", visible: :all)
end

When("I try Enter and Space on {string} after countdown closure") do |question|
  page.driver.browser.action.send_keys(:enter).send_keys(:space).perform
  # Also exercise the custom handler directly through DOM events on the disabled button.
  execute_script(<<~JS, card_for(question))
    const button = arguments[0].querySelector("button.bet-pad__button");
    for (const key of ["Enter", " "]) button.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true }));
  JS
end

Then("the countdown page should not have submitted a bet") do
  expect(evaluate_script("window.countdownRecovery.submissions")).to eq(0)
  expect(current_user.bets.count).to eq(0)
end

When("I remove {string} before its scheduled refresh") do |question|
  execute_script("arguments[0].remove()", card_for(question))
end

Then("the countdown should not request the removed card") do
  sleep 1.2
  expect(evaluate_script("window.countdownRecovery.requests")).to eq(0)
end

When("I remove {string} during its card refresh") do |question|
  expect(page).to have_css("html[data-countdown-requests='1']", visible: :all)
  execute_script("arguments[0].remove()", card_for(question))
end

Then("the removed card refresh should be aborted without retrying") do
  expect(page).to have_css("html[data-countdown-aborts='1']", visible: :all)
  sleep 1.2
  expect(evaluate_script("window.countdownRecovery.requests")).to eq(1)
end
