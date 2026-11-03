# Creator studio: posting, locking, settling, and cancelling markets.

When("I fill in the market form with:") do |table|
  table.rows_hash.each { |field, value| fill_in field, with: value }
end

When("I lock betting on {string} from my studio") do |question|
  visit studio_markets_path
  within(studio_card_for(question)) { click_button "Lock betting now" }
end

When("I declare {string} as the result of {string}") do |outcome, question|
  visit studio_markets_path
  within(studio_card_for(question)) do
    select outcome, from: "What happened?"
    click_button "Declare result"
  end
end

When("I cancel {string} from my studio") do |question|
  visit studio_markets_path
  within(studio_card_for(question)) { click_button "Cancel market" }
end

Then("my studio should list {string} as {string}") do |question, badge|
  visit studio_markets_path
  within(studio_card_for(question)) { expect(page).to have_css(".badge", exact_text: badge) }
end

Then("my studio should show a reward of {credits} credits for {string}") do |amount, question|
  visit studio_markets_path
  within(studio_card_for(question)) do
    expect(find(".settlement div", text: "Your reward").find("dd")).to have_text(helpers.credits(amount))
  end
end

Then("I should be able to declare the result of {string}") do |question|
  within(studio_card_for(question)) { expect(page).to have_button("Declare result") }
end

Then("I should not be able to declare the result of {string}") do |question|
  within(studio_card_for(question)) do
    expect(page).to have_no_button("Declare result")
    expect(page).to have_button("Lock betting now")
  end
end

# Checks the effect from a bettor's point of view, not the creator's.
Then("{string} should no longer accept predictions") do |question|
  sign_in_as(find_or_create_user("latecomer"))
  visit root_path
  within(card_for(question)) do
    expect(page).to have_content("Betting closed")
    expect(page).to have_no_button("Place bet")
  end
end
