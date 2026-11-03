Then("I should see my prediction on {string} marked {string}") do |question, status|
  expect(find("li.bet-row", text: question)).to have_css(".bet-row__status", exact_text: status)
end

Then("my activity should include {string} for {signed_credits} credits") do |description, amount|
  expect_activity(description, amount)
end
