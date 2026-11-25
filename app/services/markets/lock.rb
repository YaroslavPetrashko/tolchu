module Markets
  class Lock < ApplicationService
    def initialize(market:, now: nil)
      @market = market
      @now = now
    end

    def perform
      Market.transaction do
        @market.lock!
        now = @now || Time.current
        fail!("Betting has already closed on this market") unless @market.accepting_bets?(now)

        @market.transition!(status: :locked, locked_at: now, locks_at: now)
        @market
      end
    end
  end
end
