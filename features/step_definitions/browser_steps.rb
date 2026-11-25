# Steps for @javascript scenarios. They never use `travel`: it moves Ruby's clock, not the browser's.

TEST_CLIP = "/test-clips/clip.mp4".freeze # 3 seconds long, see spec/fixtures/files

Given("{string} posted a playable clip {string} with outcomes {string} and {string} that freezes at {float} second(s)") do |creator, question, first, second, freeze_at|
  post_market(creator: find_or_create_user(creator), question:, outcomes: [ first, second ])
    .update_columns(video_url: TEST_CLIP, freeze_at:)
end

Given("the clip for {string} has no freeze point") do |question|
  market_named(question).update_columns(freeze_at: 0)
end

Given("the clip for {string} has a freeze point of {float} second(s)") do |question, freeze_at|
  market_named(question).update_columns(freeze_at:)
end

Given("betting has closed on {string}") do |question|
  result = Markets::Lock.call(market: market_named(question))
  raise result.error if result.failure?
end

When("I replay the clip for {string}") do |question|
  card = card_for(question)
  card.find("button[aria-label='Replay clip']").click
  # Wait until it is really playing again, so the next check can't pass on the old freeze.
  expect(card.find("video").evaluate_script("this.currentTime")).to be < 1.4
end

Then("{string} should not take bets") do |question|
  within(card_for(question)) do
    expect(page).to have_css(".bet-pad__button--static", text: "Locked")
    expect(page).to have_no_css("form.bet-pad--live")
  end
end

Then("the clip for {string} should play through to the end") do |question|
  expect(page).to have_css("article.clip-card.is-ended", text: question, wait: 10)

  card = card_for(question)
  expect(card[:class].split).not_to include("is-frozen")
  video = card.find("video")
  expect(video.evaluate_script("this.currentTime")).to be_within(0.15).of(video.evaluate_script("this.duration"))
end

When("I open the feed and keep it open") do
  visit root_path
  execute_script("window.tolchuSamePage = true")
end

Then("the page should not have reloaded") do
  expect(evaluate_script("window.tolchuSamePage")).to be(true)
end

Then("the clip for {string} should freeze at {float} second(s)") do |question, freeze_at|
  expect(page).to have_css("article.clip-card.is-frozen", text: question, wait: 10)

  video = card_for(question).find("video")
  expect(video.evaluate_script("this.paused")).to be(true)
  expect(video.evaluate_script("this.currentTime")).to be_within(0.15).of(freeze_at)
end

Then("the clip for {string} should still be frozen a moment later") do |question|
  video = card_for(question).find("video")
  before = video.evaluate_script("this.currentTime")
  sleep 0.5
  expect(video.evaluate_script("this.currentTime")).to eq(before)
end

Then("betting on {string} should close on screen when the countdown runs out") do |question|
  expect(page).to have_css("article.clip-card--locked", text: question, wait: 12)
  within(card_for(question)) do
    expect(page).to have_css(".bet-pad__button--static", text: "Locked")
    expect(page).to have_no_css("form.bet-pad--live")
  end
end

When("I raise my stake on {string} to {int} credits with the arrow keys") do |question, stake|
  button = card_for(question).find("button.bet-pad__button")
  current = button.find(".bet-pad__stake").text.to_i
  (stake - current).times { button.send_keys(:arrow_up) }
end

Then("the bet button on {string} should show a stake of {int}") do |question, stake|
  within(card_for(question)) { expect(page).to have_css("button.bet-pad__button .bet-pad__stake", exact_text: stake.to_s) }
end

Then("{string} on {string} should show {string} at {string}") do |outcome, question, wins, odds|
  section = card_for(question).find("li.bet-pad__section", text: outcome)
  expect(section).to have_css(".outcome__wins", exact_text: wins)
  expect(section).to have_css(".outcome__odds", exact_text: odds)
end

# A real pointer flick: press the round button, move fast toward the outcome's side, let go.
When("I flick the bet button toward {string} on {string}") do |outcome, question|
  card = card_for(question)
  direction = card.find("li.bet-pad__section", text: outcome)["data-dir"]
  right, down = { "l" => [ -90, 0 ], "r" => [ 90, 0 ], "u" => [ 0, -90 ] }.fetch(direction)

  # The pad measures speed against a sample at least 30 ms old, and starts changing the stake
  # after a 250 ms hold, so: press, wait 60 ms, move 90 px in one go, let go.
  browser = page.driver.browser
  browser.action
         .move_to(card.find("button.bet-pad__button").native)
         .click_and_hold
         .pause(device: browser.action.pointer_inputs.first, duration: 0.06)
         .move_by(right, down, duration: 0.02)
         .release
         .perform
end

When("I pick {string} on {string} and press Enter on the bet button") do |outcome, question|
  card = card_for(question)
  # The radios are visually hidden but still reachable by keyboard, which is the point of this path.
  card.find("li.bet-pad__section", text: outcome).find("input[type=radio]", visible: :all).send_keys(:space)
  card.find("button.bet-pad__button").send_keys(:enter)
end

When("I press Enter on the bet button for {string} without picking an outcome") do |question|
  card_for(question).find("button.bet-pad__button").send_keys(:enter)
end

Then("the card for {string} should show my pending bet of {int} credits on {string}") do |question, stake, outcome|
  within(card_for(question)) do
    pill = find(".bet-pill--pending")
    expect(pill).to have_css(".bet-pill__pick", exact_text: outcome)
    expect(pill.find(".bet-pill__stake").text.squish).to eq("◎ #{stake} credits")
  end
end

# The balance sits in the pull-up menu, which is closed here; the bet response updates it in place.
Then("the balance in my menu should have updated to {credits} credits") do |amount|
  expect(page).to have_css("#wallet-balance", exact_text: amount.to_fs(:delimited), visible: :all)
end

Then("the market {string} should hint {string}") do |question, hint|
  within(card_for(question)) { expect(page).to have_css(".bet-pad__hint.is-visible", text: hint) }
end
