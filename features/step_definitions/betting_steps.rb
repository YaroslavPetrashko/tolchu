# Placing predictions (through the UI in When steps, directly in Given steps)
# and checking the parimutuel settlement.

Given("{string} has predicted {string} with {credits} credits on {string}") do |username, outcome, stake, question|
  predict!(user: find_or_create_user(username), market: market_named(question), outcome:, stake:)
end

Given("I have predicted {string} with {credits} credits on {string}") do |outcome, stake, question|
  predict!(user: current_user, market: market_named(question), outcome:, stake:)
end

Given("these predictions on {string}:") do |question, table|
  market = market_named(question)
  table.hashes.each do |row|
    predict!(user: find_or_create_user(row["user"]), market:, outcome: row["outcome"], stake: row["stake"].to_i)
  end
end

When("I predict {string} with {credits} credits on {string}") do |outcome, stake, question|
  visit root_path
  within(card_for(question)) { submit_prediction(outcome:, stake:) }
end

When("I predict {string} with {credits} credits on {string} from its page") do |outcome, stake, question|
  visit market_path(market_named(question))
  within(card_for(question)) { submit_prediction(outcome:, stake:) }
end

When("I stake {credits} credits on {string} without picking an outcome") do |stake, question|
  visit root_path
  within(card_for(question)) { submit_prediction(outcome: nil, stake:) }
end

When("I submit {string} with {credits} credits on {string} from the page I already have open") do |outcome, stake, question|
  within(card_for(question)) { submit_prediction(outcome:, stake:) }
end

Then("the bettors should end up with:") do |table|
  table.hashes.each do |row|
    user = User.find_by!(username: row["user"])
    bet = user.bets.find_by!(market: settled_market)
    expect(bet.payout).to eq(row["payout"].delete(",").to_i), "expected #{row['user']} to be paid #{row['payout']}, got #{bet.payout}"
    expect(user.balance).to eq(row["balance"].delete(",").to_i), "expected #{row['user']} to have #{row['balance']}, got #{user.balance}"
  end
end

Then("the house should keep {credits} credits") do |amount|
  expect(settled_market.house_take).to eq(amount)
end

Then("{string} should earn a creator reward of {credits} credits") do |username, amount|
  creator = User.find_by!(username:)
  expect(settled_market.creator).to eq(creator)
  expect(settled_market.creator_reward).to eq(amount)
  expect(creator.ledger_entries.creator_reward.sum(:amount)).to eq(amount)
end
