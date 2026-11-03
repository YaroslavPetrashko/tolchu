# Shared helpers for step definitions. Given steps build state directly
# (factories and services); When steps drive the real UI through Capybara.
module TolchuWorld
  DEFAULT_PASSWORD = "password123".freeze

  def find_or_create_user(username, **attributes)
    User.find_by(username:) || FactoryBot.create(:user, username:, email_address: "#{username.downcase}@example.com",
                                                        password: DEFAULT_PASSWORD, **attributes)
  end

  def sign_in_as(user)
    Capybara.reset_sessions!
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: DEFAULT_PASSWORD
    click_button "Sign in"
    expect(page).to have_css("#wallet-balance")
    @current_user = user
  end

  def current_user
    @current_user&.reload or raise "No user is signed in for this scenario"
  end

  def market_named(question)
    Market.find_by!(question:)
  end

  def post_market(creator:, question:, outcomes: [ "Yes", "No" ], locks_in: 15.minutes)
    FactoryBot.create(:market, creator:, question:, outcome_labels: outcomes, locks_at: locks_in.from_now)
  end

  def predict!(user:, market:, outcome:, stake:)
    result = Betting::PlaceBet.call(user:, market:, outcome_id: market.outcomes.find_by!(label: outcome).id, stake:)
    raise "Setup bet failed: #{result.error}" if result.failure?
  end

  def settle!(market, outcome_label)
    Markets::Lock.call(market:) if market.accepting_bets?
    result = Markets::Resolve.call(market: market.reload, winning_outcome_id: market.outcomes.find_by!(label: outcome_label).id)
    raise "Settlement failed: #{result.error}" if result.failure?

    @settled_market = market.reload
  end

  def settled_market
    @settled_market or raise "No market has been settled in this scenario"
  end

  def card_for(question)
    find("article.clip-card", text: question)
  end

  def studio_card_for(question)
    find("article.studio-card", text: question)
  end

  def helpers
    ApplicationController.helpers
  end

  # Form helpers shared by the When steps.
  def submit_sign_up(username:, email:, password:, confirmation:)
    fill_in "Username", with: username
    fill_in "Email", with: email
    fill_in "Password", with: password
    fill_in "Confirm password", with: confirmation
    click_button "Create account"
  end

  def submit_sign_in(email, password)
    fill_in "Email", with: email
    fill_in "Password", with: password
    click_button "Sign in"
  end

  def submit_prediction(outcome:, stake:)
    choose outcome if outcome
    fill_in "Stake", with: stake
    click_button "Place bet"
  end

  def expect_activity(description, amount)
    row = find("table.ledger tbody tr", text: description, match: :first)
    expect(row).to have_css("td", exact_text: helpers.signed_credits(amount))
  end
end

World(TolchuWorld)
World(FactoryBot::Syntax::Methods)
World(ActiveSupport::Testing::TimeHelpers)

After { travel_back }
