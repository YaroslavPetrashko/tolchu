require "rails_helper"

RSpec.describe User do
  subject { build(:user) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_length_of(:username).is_at_least(3).is_at_most(20) }
    it { is_expected.to validate_uniqueness_of(:username).case_insensitive }
    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to validate_uniqueness_of(:email_address).ignoring_case_sensitivity }
    it { is_expected.to validate_length_of(:password).is_at_least(8) }
    it { is_expected.to validate_numericality_of(:balance).only_integer.is_greater_than_or_equal_to(0) }

    it "only allows letters, numbers, and underscores in usernames" do
      expect(build(:user, username: "stunt_lab_9")).to be_valid
      expect(build(:user, username: "stunt lab")).not_to be_valid
      expect(build(:user, username: "<script>")).not_to be_valid
    end

    it "rejects malformed email addresses" do
      user = build(:user, email_address: "not-an-email")
      expect(user).not_to be_valid
      expect(user.errors[:email_address]).to include("doesn't look like an email address")
    end

    it "enforces username uniqueness case-insensitively in the database too" do
      create(:user, username: "Hooper")
      duplicate = build(:user, username: "hooper")
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "refuses a negative balance at the database level" do
      user = create(:user)
      expect { user.update_column(:balance, -1) }.to raise_error(ActiveRecord::StatementInvalid, /users_balance_non_negative/)
    end
  end

  describe "normalization" do
    it "downcases and strips email addresses" do
      expect(build(:user, email_address: "  Fan@Example.COM ").email_address).to eq("fan@example.com")
    end

    it "strips whitespace around usernames" do
      expect(build(:user, username: "  hooper ").username).to eq("hooper")
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:bets) }
    it { is_expected.to have_many(:ledger_entries) }
    it { is_expected.to have_many(:created_markets).class_name("Market").with_foreign_key(:creator_id) }
  end

  describe ".register" do
    let(:attributes) { { username: "rookie", email_address: "rookie@example.com", password: "password123", password_confirmation: "password123" } }

    it "creates the user with the starting credits" do
      user = described_class.register(attributes)

      expect(user).to be_persisted
      expect(user.reload.balance).to eq(User::STARTING_CREDITS)
    end

    it "backs the starting balance with a ledger entry" do
      user = described_class.register(attributes)

      entry = user.ledger_entries.sole
      expect(entry).to have_attributes(kind: "starting_credits", amount: 1_000, balance_after: 1_000)
    end

    it "returns an unsaved user with errors when the details are invalid" do
      user = described_class.register(attributes.merge(password_confirmation: "nope"))

      expect(user).not_to be_persisted
      expect(user.errors[:password_confirmation]).to be_present
      expect(LedgerEntry.count).to eq(0)
    end
  end

  describe "#bet_on and #creator_of?" do
    let(:user) { create(:user) }
    let(:market) { create(:market) }

    it "finds the user's bet on a market" do
      bet = place_bet(user:, market:, outcome: "Lands it", stake: 10)
      expect(user.bet_on(market)).to eq(bet)
      expect(create(:user).bet_on(market)).to be_nil
    end

    it "knows whether the user created a market" do
      expect(market.creator.creator_of?(market)).to be(true)
      expect(user.creator_of?(market)).to be(false)
    end
  end
end
