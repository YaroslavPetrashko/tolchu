module Markets
  # Lets a creator close betting early, right before the play begins.
  class Lock < ApplicationService
    def initialize(market:, now: Time.current)
      @market = market
      @now = now
    end

    def perform
      Market.transaction do
        @market.lock!
        fail!("Betting has already closed on this market") unless @market.accepting_bets?(@now)

        @market.update!(status: :locked, locked_at: @now, locks_at: @now)
        @market
      end
    end
  end
end
