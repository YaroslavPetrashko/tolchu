require "rails_helper"

RSpec.describe LedgerEntry do
  subject { build(:user).ledger_entries.build(kind: :payout, amount: 10, balance_after: 10) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:market).optional }
  it { is_expected.to belong_to(:bet).optional }
  it { is_expected.to validate_numericality_of(:amount).only_integer.is_other_than(0) }
  it { is_expected.to validate_numericality_of(:balance_after).only_integer.is_greater_than_or_equal_to(0) }

  it "only accepts known kinds" do
    entry = build(:user).ledger_entries.build(kind: "bonus_points", amount: 10, balance_after: 10)
    expect(entry).not_to be_valid
  end

  it "is immutable once written" do
    user = create(:user)
    user.wallet.credit!(5, kind: :payout)
    entry = user.ledger_entries.sole

    expect(entry).to be_readonly
    expect { entry.update!(amount: 500) }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  describe "#description" do
    let(:user) { create(:user) }
    let(:market) { create(:market, question: "Will it land?") }

    def entry(kind)
      user.ledger_entries.build(kind:, amount: 1, balance_after: 1, market: (market unless kind == :starting_credits))
    end

    it "describes each kind of movement" do
      expect(entry(:starting_credits).description).to eq("Welcome bonus")
      expect(entry(:stake).description).to eq("Prediction on “Will it land?”")
      expect(entry(:payout).description).to eq("Won “Will it land?”")
      expect(entry(:refund).description).to eq("Refund for “Will it land?”")
      expect(entry(:creator_reward).description).to eq("Creator reward for “Will it land?”")
    end
  end
end
