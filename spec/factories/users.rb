FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "fan_#{n}" }
    sequence(:email_address) { |n| "fan#{n}@example.com" }
    password { "password123" }
    balance { User::STARTING_CREDITS }
  end
end
