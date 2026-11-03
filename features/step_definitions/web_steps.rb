# Generic navigation and page-content steps.

Given("I am on {page}") do |page_name|
  visit path_to(page_name)
end

When("I go to {page}") do |page_name|
  visit path_to(page_name)
end

When("I press {string}") do |button|
  click_button button
end

When("I follow {string}") do |link|
  click_link link
end

When("I select {string} from {string}") do |option, field|
  select option, from: field
end

When("{int} minute(s) pass") do |minutes|
  travel minutes.minutes
end

Then("I should see {string}") do |text|
  expect(page).to have_content(text)
end

Then("I should not see {string}") do |text|
  expect(page).to have_no_content(text)
end

Then("I should be on {page}") do |page_name|
  expect(page).to have_current_path(path_to(page_name))
end

Then("I should see {string} before {string}") do |first, second|
  expect(page).to have_content(first)
  expect(page).to have_content(second)
  expect(page.text.index(first)).to be < page.text.index(second)
end

Then("I should not see a {string} button") do |button|
  expect(page).to have_no_button(button)
end
