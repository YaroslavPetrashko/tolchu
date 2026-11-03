# Immutable audit trail of credit movements. Positive amounts are credits to
# the user, negative amounts are debits. Always written through Wallet.
class LedgerEntry < ApplicationRecord
  belongs_to :user
  belongs_to :market, optional: true
  belongs_to :bet, optional: true

  enum :kind, {
    starting_credits: "starting_credits",
    stake: "stake",
    payout: "payout",
    refund: "refund",
    creator_reward: "creator_reward"
  }, validate: true

  validates :amount, numericality: { only_integer: true, other_than: 0 }
  validates :balance_after, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def readonly?
    persisted? || super
  end

  def description
    case kind.to_sym
    when :starting_credits then "Welcome bonus"
    when :stake then "Prediction on “#{market&.question}”"
    when :payout then "Won “#{market&.question}”"
    when :refund then "Refund for “#{market&.question}”"
    when :creator_reward then "Creator reward for “#{market&.question}”"
    end
  end
end
