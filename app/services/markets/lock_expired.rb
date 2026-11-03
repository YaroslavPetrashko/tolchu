module Markets
  # Persists the "locked" status for open markets whose betting window has
  # passed. Bets are already refused by the clock check; this keeps the status
  # column honest for reporting. Run via `bin/rails markets:lock_expired`.
  class LockExpired < ApplicationService
    def initialize(now: Time.current)
      @now = now
    end

    # Returns the number of markets locked.
    def perform
      Market.open.where(locks_at: ..@now).update_all([ "status = ?, locked_at = locks_at, updated_at = ?", "locked", @now ])
    end
  end
end
