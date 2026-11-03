class MarketsController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]

  def index
    @feed = MarketFeed.new(viewer: Current.user)
  end

  def show
    @market = Market.includes(:creator, :outcomes, :winning_outcome).find(params[:id])
    @viewer_bet = Current.user&.bet_on(@market)
  end
end
