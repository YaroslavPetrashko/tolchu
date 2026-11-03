# Setting up markets and checking how they appear on the feed.

Given("{string} posted {string} with outcomes {string} and {string}") do |creator, question, first, second|
  post_market(creator: find_or_create_user(creator), question:, outcomes: [ first, second ])
end

Given("{string} posted {string} that locks in {int} minute(s)") do |creator, question, minutes|
  post_market(creator: find_or_create_user(creator), question:, locks_in: minutes.minutes)
end

Given("I posted {string} with outcomes {string} and {string}") do |question, first, second|
  post_market(creator: current_user, question:, outcomes: [ first, second ])
end

Given("{string} locks in {int} minute(s)") do |question, minutes|
  market_named(question).update_columns(locks_at: minutes.minutes.from_now)
end

Given("I have locked betting on {string}") do |question|
  result = Markets::Lock.call(market: market_named(question))
  raise result.error if result.failure?
end

Given("{string} has been settled as {string}") do |question, outcome|
  settle!(market_named(question), outcome)
end

When("{string} is settled as {string}") do |question, outcome|
  settle!(market_named(question), outcome)
end

Given("{string} has been cancelled") do |question|
  result = Markets::Cancel.call(market: market_named(question))
  raise result.error if result.failure?
end

Then("the market {string} should be marked {string}") do |question, badge|
  within(card_for(question)) { expect(page).to have_css(".badge", exact_text: badge) }
end

Then("the market {string} should say {string}") do |question, text|
  within(card_for(question)) { expect(page).to have_content(text) }
end

Then("the market {string} should have {credits} credits in the pool from {int} prediction(s)") do |question, amount, count|
  within(card_for(question)) do
    expect(find(".clip-card__pool")).to have_text("#{helpers.credits(amount)} in the pool · #{helpers.pluralize(count, 'prediction')}")
  end
end

Then("the market {string} should show {string} with {int}% of the pool") do |question, outcome, share|
  within(card_for(question)) do
    expect(find("li.outcome", text: outcome)).to have_css(".outcome__share", exact_text: "#{share}%")
  end
end

Then("the market {string} should offer {string}") do |question, link|
  within(card_for(question)) { expect(page).to have_link(link) }
end

Then("the market {string} should not offer a {string} button") do |question, button|
  within(card_for(question)) { expect(page).to have_no_button(button) }
end

Then("the feed should include {string} with outcomes {string}") do |question, outcomes|
  visit root_path
  within(card_for(question)) do
    outcomes.split(",").map(&:strip).each { |label| expect(page).to have_css("li.outcome", text: label) }
  end
end
