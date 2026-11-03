class WalletsController < ApplicationController
  ACTIVITY_LIMIT = 50

  def show
    @user = Current.user
    @bets = @user.bets.includes(:outcome, market: :winning_outcome).order(created_at: :desc, id: :desc).to_a
    @entries = @user.ledger_entries.includes(:market).order(created_at: :desc, id: :desc).limit(ACTIVITY_LIMIT)
    @settled_bets = @bets.select { |bet| bet.won? || bet.lost? }
  end
end
