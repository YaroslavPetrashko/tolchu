Given("a user {string} exists") do |username|
  find_or_create_user(username)
end

Given("a creator {string} exists") do |username|
  find_or_create_user(username)
end

Given("I am signed in as {string}") do |username|
  sign_in_as(find_or_create_user(username))
end

Given("my balance is {credits} credits") do |amount|
  current_user.update!(balance: amount)
end

When("I sign up as {string} with email {string} and password {string}") do |username, email, password|
  submit_sign_up(username:, email:, password:, confirmation: password)
end

When("I sign up as {string} with email {string}, password {string} and confirmation {string}") do |username, email, password, confirmation|
  submit_sign_up(username:, email:, password:, confirmation:)
end

When("I sign in with {string} and {string}") do |email, password|
  visit new_session_path
  submit_sign_in(email, password)
end

When("I sign in with {string} and {string} on this page") do |email, password|
  submit_sign_in(email, password)
end

When("I follow my balance") do
  find(".balance-pill").click
end

Then("my balance should be {credits} credits") do |amount|
  visit root_path unless page.has_css?("#wallet-balance")
  expect(page).to have_css("#wallet-balance", exact_text: amount.to_fs(:delimited))
end

Then("I should not be signed in") do
  expect(page).to have_no_css("#wallet-balance")
  expect(page).to have_link("Sign in")
end

Then("{string} should have {credits} credits") do |username, amount|
  expect(User.find_by!(username:).balance).to eq(amount)
end

Then("my wallet should show {string} for {signed_credits} credits") do |description, amount|
  visit wallet_path
  expect_activity(description, amount)
end
