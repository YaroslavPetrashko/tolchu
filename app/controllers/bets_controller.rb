class BetsController < ApplicationController
  before_action :set_market

  def create
    result = Betting::PlaceBet.call(user: Current.user, market: @market, outcome_id: params[:outcome_id], stake: stake_param)

    if result.success?
      bet = result.value
      flash.now[:notice] = "Prediction locked in: #{bet.outcome.label} for #{bet.stake} credits."
      respond_to do |format|
        format.turbo_stream { render_card_update(bet) }
        format.html { redirect_to return_path, notice: flash.now[:notice] }
      end
    else
      flash.now[:alert] = result.error
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.update("flash", partial: "layouts/flash"), status: :unprocessable_entity }
        format.html { redirect_to return_path, alert: result.error }
      end
    end
  end

  private
    def set_market
      @market = Market.find(params[:market_id])
    end

    # Non-numeric input becomes nil so the model reports a friendly validation error.
    def stake_param
      Integer(params[:stake].to_s, exception: false)
    end

    def render_card_update(bet)
      market = Market.includes(:creator, :outcomes, :winning_outcome).find(@market.id)
      render turbo_stream: [
        turbo_stream.replace(market, partial: "markets/market", locals: { market:, viewer_bet: bet, context: return_context }),
        turbo_stream.update("wallet-balance", Current.user.reload.balance.to_fs(:delimited)),
        turbo_stream.update("flash", partial: "layouts/flash")
      ]
    end

    def return_context
      params[:context] == "feed" ? "feed" : "page"
    end

    def return_path
      return_context == "feed" ? root_path(anchor: helpers.dom_id(@market)) : market_path(@market)
    end
end
