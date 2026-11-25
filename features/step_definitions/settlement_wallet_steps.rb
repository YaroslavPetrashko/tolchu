Given("the recorded result of {string} is sealed as {string}") do |question, answer|
  market_named(question).outcomes.find_by!(label: answer).update!(sealed_winner: true)
end

Then("the sealed clip {string} should settle on screen") do |question|
  expect(page).to have_css("article.clip-card--resolved", text: question, wait: 12)
end

When("I open the account menu") do
  find('button[aria-label="Open menu"]').click
end
