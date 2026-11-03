class User < ApplicationRecord
  STARTING_CREDITS = 1_000

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :bets, dependent: :restrict_with_error
  has_many :ledger_entries, dependent: :restrict_with_error
  has_many :created_markets, class_name: "Market", foreign_key: :creator_id,
           inverse_of: :creator, dependent: :restrict_with_error

  normalizes :email_address, with: ->(email) { email.strip.downcase }
  normalizes :username, with: ->(username) { username.strip }

  validates :username, presence: true, length: { in: 3..20 },
                       format: { with: /\A[a-zA-Z0-9_]+\z/, message: "can only use letters, numbers, and underscores" },
                       uniqueness: { case_sensitive: false }
  validates :email_address, presence: true, uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP, message: "doesn't look like an email address" }
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :balance, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Creates the account and grants the play-money starting balance in one transaction,
  # so every user's balance is backed by a ledger entry from day one.
  def self.register(attributes)
    new(attributes).tap do |user|
      transaction do
        user.save && user.wallet.credit!(STARTING_CREDITS, kind: :starting_credits)
      end
    end
  end

  def wallet
    Wallet.new(self)
  end

  def bet_on(market)
    bets.find_by(market:)
  end

  def creator_of?(market)
    market.creator_id == id
  end
end
