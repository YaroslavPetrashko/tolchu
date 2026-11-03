# A "what happens next?" question attached to a short clip. Bets go into a
# parimutuel pool that is split among the correct predictions once the creator
# declares the result.
#
# Lifecycle: open -> locked -> resolved, or open/locked -> cancelled (full refund).
# A market whose locks_at has passed stops taking bets immediately, even if the
# status column still says "open". The clock is the source of truth for the lock.
class Market < ApplicationRecord
  MIN_OUTCOMES = 2
  MAX_OUTCOMES = 4
  # Label => minutes. Offered to creators instead of a raw datetime so the
  # deadline is unambiguous regardless of the creator's time zone.
  BETTING_WINDOWS = {
    "1 minute" => 1,
    "5 minutes" => 5,
    "15 minutes" => 15,
    "1 hour" => 60,
    "6 hours" => 360,
    "24 hours" => 1_440,
    "3 days" => 4_320
  }.freeze

  belongs_to :creator, class_name: "User", inverse_of: :created_markets
  belongs_to :winning_outcome, class_name: "Outcome", optional: true
  has_many :outcomes, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :market
  has_many :bets, dependent: :restrict_with_error

  enum :status, { open: "open", locked: "locked", resolved: "resolved", cancelled: "cancelled" },
       default: :open, validate: true

  accepts_nested_attributes_for :outcomes, reject_if: ->(attributes) { attributes["label"].blank? }

  # Virtual attribute used by the studio form; converted into locks_at on create.
  attribute :betting_window_minutes, :integer

  validates :question, presence: true, length: { maximum: 140 }
  validates :description, length: { maximum: 500 }
  validates :video_url, presence: true, length: { maximum: 500 },
                        format: { with: %r{\A(https?://|/)\S+\z}i, message: "must be an http(s) link to a video file" }
  validates :freeze_at, numericality: { greater_than_or_equal_to: 0, less_than: 600 }
  validates :locks_at, presence: true
  validates :betting_window_minutes, inclusion: { in: BETTING_WINDOWS.values, message: "isn't one of the offered windows" },
                                     allow_nil: true
  validate :locks_at_must_be_in_the_future, on: :create
  validate :outcome_count_within_limits
  validate :outcome_labels_must_be_unique

  before_validation :apply_betting_window, on: :create
  before_validation :assign_outcome_positions

  scope :accepting_bets, ->(now = Time.current) { open.where(arel_table[:locks_at].gt(now)) }
  scope :awaiting_result, ->(now = Time.current) { locked.or(open.where(arel_table[:locks_at].lteq(now))) }

  def accepting_bets?(now = Time.current)
    open? && now < locks_at
  end

  def awaiting_result?(now = Time.current)
    locked? || (open? && now >= locks_at)
  end

  def settled?
    resolved? || cancelled?
  end

  # What viewers should see right now: :open, :locked, :resolved or :cancelled.
  def phase(now = Time.current)
    return status.to_sym if settled?

    accepting_bets?(now) ? :open : :locked
  end

  def contest_score
    Parimutuel.contest_score(outcomes.map(&:pool))
  end

  # Payout multiple a new bet of `stake` on `outcome` would earn if it won, given the current pool.
  def projected_multiplier(outcome, stake: 0)
    Parimutuel.projected_multiplier(outcome_pool: outcome.pool, total_pool: total_pool, stake:)
  end

  private
    def apply_betting_window
      self.locks_at = Time.current + betting_window_minutes.minutes if betting_window_minutes.present?
    end

    def assign_outcome_positions
      outcomes.each_with_index { |outcome, index| outcome.position = index }
    end

    def locks_at_must_be_in_the_future
      errors.add(:locks_at, "must be in the future") if locks_at.present? && locks_at <= Time.current
    end

    def outcome_count_within_limits
      count = outcomes.reject(&:marked_for_destruction?).size
      return if count.between?(MIN_OUTCOMES, MAX_OUTCOMES)

      errors.add(:outcomes, "must have between #{MIN_OUTCOMES} and #{MAX_OUTCOMES} options (you have #{count})")
    end

    def outcome_labels_must_be_unique
      labels = outcomes.map { |outcome| outcome.label.to_s.strip.downcase }.compact_blank
      errors.add(:outcomes, "must all be different") if labels.uniq.size != labels.size
    end
end
