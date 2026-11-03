module Markets
  # Lets a creator close betting early, right before the play begins.
  class Lock < ApplicationService
    # `now` is for tests; by default the clock is read after the row lock is held, so the recorded
    # lock time is never earlier than a bet that committed while we waited for the lock.
    def initialize(market:, now: nil)
      @market = market
      @now = now
    end

    def perform
      Market.transaction do
        @market.lock!
        now = @now || Time.current
        fail!("Betting has already closed on this market") unless @market.accepting_bets?(now)

        @market.update!(status: :locked, locked_at: now, locks_at: now)
        @market
      end
    end
  end
end
