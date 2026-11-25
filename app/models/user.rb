class User < ApplicationRecord
  STARTING_CREDITS = 1_000
  # Stricter than URI::MailTo::EMAIL_REGEXP, which accepts "fan@localhost": the domain needs a dot and a real ending.
  EMAIL_FORMAT = /\A[a-z0-9.!#$%&'*+\/=?^_`{|}~-]+@(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}\z/i

  # Set at public sign-up to also refuse throwaway inboxes and domains that can't receive mail.
  attr_accessor :screen_email

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
                            format: { with: EMAIL_FORMAT, message: "doesn't look like an email address" }
  validate :email_must_be_reachable, if: :screen_email
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :balance, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Public sign-up: registers the account only if its email passes the screening.
  def self.sign_up(attributes)
    register(attributes) { |user| user.screen_email = true }
  end

  def self.register(attributes)
    new(attributes).tap do |user|
      yield user if block_given?
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

  private
    def email_must_be_reachable
      return if errors.include?(:email_address)

      domain = EmailDomain.from_address(email_address)
      if domain.disposable?
        errors.add(:email_address, "can't be a temporary or disposable address")
      elsif Rails.configuration.x.check_email_dns && !domain.receives_mail?
        errors.add(:email_address, "uses a domain that can't receive email. Check for a typo")
      end
    end
end
