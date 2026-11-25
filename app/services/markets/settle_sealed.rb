module Markets
  # Settles every sealed market whose betting window has closed. It runs inside
  # page loads (the feed, a clip page, a card refresh), so it must be cheap when
  # nothing is due and must never raise: a passing database clash is retried,
  # and a market that still cannot settle is logged and skipped so the rest
  # settle and the page renders.
  class SettleSealed < ApplicationService
    MAX_ATTEMPTS = 3
    # Errors that come from timing, not from the market itself. The whole
    # settlement is one transaction that has been rolled back, so trying again
    # is safe.
    PASSING_ERRORS = [
      ActiveRecord::TransactionRollbackError, # deadlocks, serialization failures
      ActiveRecord::LockWaitTimeout,
      ActiveRecord::QueryCanceled
    ].freeze

    def initialize(now: Time.current, scope: Market.all)
      @now = now
      @scope = scope
    end

    def perform
      due = @scope.due_for_sealed_settlement(@now)
      return 0 unless due.exists?

      due.includes(:sealed_winner).to_a.count { |market| settle(market) }
    end

    private
      def settle(market)
        attempts = 0
        begin
          attempts += 1
          Resolve.call(market:, winning_outcome_id: market.sealed_winner.id).success?
        rescue *PASSING_ERRORS
          retry if attempts < MAX_ATTEMPTS
          raise
        end
      rescue StandardError => e
        Rails.logger.error("[Markets::SettleSealed] market #{market.id} could not be settled: #{e.class}: #{e.message}")
        Rails.error.report(e, handled: true, context: { market_id: market.id })
        false
      end
  end
end
