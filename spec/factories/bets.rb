FactoryBot.define do
  # Builds a bet row directly. Prefer Betting::PlaceBet (see `place_bet` helper)
  # when the wallet and pool side effects matter.
  factory :bet do
    user
    market
    outcome { market.outcomes.first }
    stake { 10 }
  end
end
