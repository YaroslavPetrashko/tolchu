FactoryBot.define do
  factory :outcome do
    market
    sequence(:label) { |n| "Outcome #{n}" }
  end
end
