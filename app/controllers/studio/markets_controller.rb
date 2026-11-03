module Studio
  # Creator tools: post a market for a clip, lock betting right before the play,
  # declare the result, or cancel and refund. Creators only see their own markets.
  class MarketsController < ApplicationController
    # Markets that need the creator's attention come first.
    PHASE_ORDER = { locked: 0, open: 1, resolved: 2, cancelled: 3 }.freeze

    before_action :set_market, only: %i[ lock resolve cancel ]

    def index
      @markets = Current.user.created_markets.includes(:outcomes, :winning_outcome).order(created_at: :desc, id: :desc)
                        .sort_by.with_index { |market, index| [ PHASE_ORDER.fetch(market.phase), index ] }
    end

    def new
      @market = Current.user.created_markets.build(betting_window_minutes: 15, freeze_at: 0)
      build_blank_outcomes
    end

    def create
      @market = Current.user.created_markets.build(market_params)
      if @market.save
        redirect_to studio_markets_path, notice: "Your market is live! Betting closes #{helpers.time_ago_in_words(@market.locks_at)} from now."
      else
        build_blank_outcomes
        render :new, status: :unprocessable_entity
      end
    end

    def lock
      result = Markets::Lock.call(market: @market)
      redirect_with result, notice: "Betting is locked on “#{@market.question}”. Declare the result once the play is over."
    end

    def resolve
      result = Markets::Resolve.call(market: @market, winning_outcome_id: params[:winning_outcome_id])
      redirect_with result, notice: -> { "Result declared: #{@market.winning_outcome.label}. Payouts sent!" }
    end

    def cancel
      result = Markets::Cancel.call(market: @market)
      redirect_with result, notice: "“#{@market.question}” was cancelled and every stake was refunded."
    end

    private
      def set_market
        @market = Current.user.created_markets.find(params[:id])
      end

      def market_params
        params.expect(market: [ :question, :description, :video_url, :freeze_at, :betting_window_minutes,
                                outcomes_attributes: [ [ :label ] ] ])
      end

      def build_blank_outcomes
        (Market::MAX_OUTCOMES - @market.outcomes.size).times { @market.outcomes.build }
      end

      def redirect_with(result, notice:)
        if result.success?
          redirect_to studio_markets_path, notice: notice.respond_to?(:call) ? notice.call : notice, status: :see_other
        else
          redirect_to studio_markets_path, alert: result.error, status: :see_other
        end
      end
  end
end
