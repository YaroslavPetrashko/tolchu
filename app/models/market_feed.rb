# The home feed: markets you can still bet on (closing soonest first), then
# markets waiting for a result, then the most recent results. Cancelled markets
# are left out.
class MarketFeed
  RECENT_RESULTS_LIMIT = 12

  attr_reader :viewer, :now

  def initialize(viewer: nil, now: Time.current)
    @viewer = viewer
    @now = now
  end

  def markets
    @markets ||= [
      base.accepting_bets(now).order(:locks_at, :id),
      base.awaiting_result(now).order(locks_at: :desc, id: :desc),
      base.resolved.order(resolved_at: :desc, id: :desc).limit(RECENT_RESULTS_LIMIT)
    ].flat_map(&:to_a)
  end

  def bet_for(market)
    viewer_bets[market.id]
  end

  private
    def base
      Market.includes(:creator, :outcomes, :winning_outcome)
    end

    def viewer_bets
      @viewer_bets ||= viewer ? viewer.bets.where(market_id: markets.map(&:id)).includes(:outcome).index_by(&:market_id) : {}
    end
end
