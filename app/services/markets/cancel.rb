module Markets
  # Voids a market that hasn't been settled yet and refunds every stake in full.
  class Cancel < ApplicationService
    # `now` is for tests; by default the clock is read after the market row lock is held.
    def initialize(market:, now: nil)
      @market = market
      @now = now
    end

    def perform
      Market.transaction do
        @market.lock!
        now = @now || Time.current
        fail!("This market has already been settled") if @market.settled?

        bets = @market.bets.includes(:user).order(:id).to_a
        User.where(id: bets.map(&:user_id)).order(:id).lock.load
        bets.each do |bet|
          bet.update!(status: :refunded, payout: bet.stake)
          bet.user.wallet.credit!(bet.stake, kind: :refund, market: @market, bet:)
        end
        @market.update!(status: :cancelled, cancelled_at: now, refunded: true, house_take: 0, creator_reward: 0)
        @market
      end
    end
  end
end
