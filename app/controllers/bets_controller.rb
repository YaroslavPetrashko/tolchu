class BetsController < ApplicationController
  before_action :set_market
  rate_limit to: 20, within: 1.minute, only: :create, by: -> { Current.user.id }, with: :too_many_bets

  def create
    respond_to_bet Betting::PlaceBet.call(user: Current.user, market: @market, outcome_id: params[:outcome_id], stake: stake_param)
  end

  def update
    bet = Current.user.bets.find_by!(id: params[:id], market: @market)
    respond_to_bet Betting::ChangeBet.call(bet:, outcome_id: params[:outcome_id], stake: stake_param)
  end

  private
    def respond_to_bet(result)
      if result.success?
        respond_to do |format|
          format.turbo_stream { render_card_update(result.value) }
          format.html { redirect_to return_path }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(helpers.dom_id(@market, :bet_hint), partial: "markets/bet_hint",
                                                      locals: { market: @market, message: result.error }),
                   status: :unprocessable_entity
          end
          format.html { redirect_to return_path, flash: { bet_error: result.error, bet_error_market_id: @market.id } }
        end
      end
    end

    def too_many_bets
      message = "You're placing bets too fast. Wait a minute and try again."
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = message
          render turbo_stream: turbo_stream.update("flash", partial: "layouts/flash"), status: :too_many_requests
        end
        format.html { redirect_to return_path, alert: message }
      end
    end

    def set_market
      @market = Market.find(params[:market_id])
    end

    def stake_param
      Integer(params[:stake].to_s, exception: false)
    end

    def render_card_update(bet)
      market = Market.includes(:creator, :outcomes, :winning_outcome).find(@market.id)
      user = Current.user.reload
      render turbo_stream: [
        turbo_stream.replace(market, partial: "markets/market", locals: { market:, viewer_bet: bet, context: return_context }),
        turbo_stream.replace("wallet-balance", partial: "layouts/wallet_balance", locals: { user: }),
        turbo_stream.replace("session-strip", partial: "markets/session_strip")
      ]
    end

    def return_context
      params[:context] == "feed" ? "feed" : "page"
    end

    def return_path
      return_context == "feed" ? root_path(anchor: helpers.dom_id(@market)) : market_path(@market)
    end
end
