class Outcome < ApplicationRecord
  belongs_to :market, inverse_of: :outcomes
  has_many :bets, dependent: :restrict_with_error

  normalizes :label, with: ->(label) { label.strip }

  validates :label, presence: true, length: { maximum: 40 }
  validates :pool, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Fraction of the market's pool riding on this outcome (0.0 to 1.0).
  def share_of_pool
    market.total_pool.zero? ? 0.0 : pool.fdiv(market.total_pool)
  end

  def winner?
    market.winning_outcome_id == id
  end
end
