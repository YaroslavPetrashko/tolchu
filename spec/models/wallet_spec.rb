require "rails_helper"

RSpec.describe Wallet do
  let(:user) { create(:user, balance: 100) }
  let(:wallet) { user.wallet }

  describe "#credit!" do
    it "increases the balance and records a ledger entry" do
      wallet.credit!(25, kind: :payout)

      expect(user.reload.balance).to eq(125)
      expect(user.ledger_entries.sole).to have_attributes(kind: "payout", amount: 25, balance_after: 125)
    end

    it "links the entry to a market and bet when given" do
      market = create(:market)
      bet = create(:bet, market:)
      wallet.credit!(10, kind: :refund, market:, bet:)

      expect(user.ledger_entries.sole).to have_attributes(market:, bet:)
    end
  end

  describe "#debit!" do
    it "decreases the balance and records a negative ledger entry" do
      wallet.debit!(40, kind: :stake)

      expect(wallet.balance).to eq(60)
      expect(user.ledger_entries.sole).to have_attributes(amount: -40, balance_after: 60)
    end

    it "allows spending the balance down to exactly zero" do
      wallet.debit!(100, kind: :stake)
      expect(user.reload.balance).to eq(0)
    end

    it "raises and changes nothing when the balance can't cover it" do
      expect { wallet.debit!(101, kind: :stake) }.to raise_error(Wallet::InsufficientCredits)

      expect(user.reload.balance).to eq(100)
      expect(user.ledger_entries).to be_empty
    end
  end

  it "only moves positive whole amounts" do
    [ 0, -5, 1.5, "10", nil ].each do |amount|
      expect { wallet.credit!(amount, kind: :payout) }.to raise_error(ArgumentError)
    end
  end

  it "keeps the cached balance equal to the ledger sum" do
    wallet.credit!(30, kind: :payout)
    wallet.debit!(45, kind: :stake)
    wallet.credit!(5, kind: :refund)

    expect(user.reload.balance).to eq(100 + user.ledger_entries.sum(:amount))
  end
end
