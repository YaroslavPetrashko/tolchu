---
title: "Sealed results: settle pre-recorded clips automatically at lock"
labels: ["type: feature", "area: betting-engine", "area: creator-tools", "priority: P1 · iteration 2"]
milestone: "Iteration 2"
---
## Summary
As a creator posting a pre-recorded clip, I want to seal the real result when I publish. The market then settles itself as soon as betting closes, and bettors get paid without waiting for me to come back to the Studio.

## Context
- **Settlement is manual today.** [`Studio::MarketsController#resolve`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/studio/markets_controller.rb) calls [`Markets::Resolve`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/resolve.rb) with `market:, winning_outcome_id:, now:`. `Resolve` locks the row, refuses markets that are already settled or still open, settles through `Parimutuel::Settlement`, and pays out through `Wallet`.
- **The clock closes betting.** `Market.awaiting_result` covers markets that are `locked`, plus `open` markets past `locks_at` ([`market.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/market.rb)). `bin/rails markets:lock_expired` ([`lib/tasks/markets.rake`](https://github.com/YaroslavPetrashko/tolchu/blob/main/lib/tasks/markets.rake)) persists the locked status; #23 will schedule it.
- **No job backend.** Solid Queue was skipped and there's no worker dyno, so nothing can run on its own at `locks_at`.
- **Outcomes have no ids while the form is filled in.** They're created through `accepts_nested_attributes_for :outcomes`, which drops blank labels and renumbers positions.

## Suggested implementation
1. **Migration and association.** `add_reference :markets, :sealed_outcome, foreign_key: { to_table: :outcomes }` (nullable bigint, indexed), plus `belongs_to :sealed_outcome, class_name: "Outcome", optional: true`.
2. **Form and model.**
   - Add a virtual `attribute :sealed, :boolean, default: false` to `Outcome`.
   - In [`studio/markets/new.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/studio/markets/new.html.erb), add one checkbox per outcome row, labelled "Outcome N is what happens", with the hint "Pre-recorded? Tick what actually happens and the market settles itself when betting closes."
   - Permit `outcomes_attributes: [ [ :label, :sealed ] ]`.
   - In `Market`, validate that at most one outcome is sealed and that `sealed_outcome.market_id == id`.
   - Add an `after_create` that copies the ticked outcome's id into `sealed_outcome_id`. Declare it after the `has_many`, so the outcomes are already saved when it runs.
3. **Never render it.**
   - No sealed markers in feed, show or card HTML.
   - The Studio card shows "Settles automatically when betting closes" instead of the "Declare result" form.
   - `Markets::Resolve` refuses any winner other than the sealed one.
4. **New service `Markets::SettleSealed`.**

```ruby
module Markets
  # Resolves pre-recorded markets with their sealed result once betting has closed.
  class SettleSealed < ApplicationService
    def initialize(now: Time.current, limit: nil)
      @now = now
      @limit = limit
    end

    def perform # => number of markets settled
      Market.awaiting_result(@now).where.not(sealed_outcome_id: nil).order(:locks_at, :id).limit(@limit).to_a
            .count { |market| Resolve.call(market:, winning_outcome_id: market.sealed_outcome_id, now: @now).success? }
    end
  end
end
```
   `Resolve` takes the row lock and re-checks `settled?`, so two requests settling the same market at once are safe: the second one just gets a failure result.
5. **When it runs.**
   - On demand: a `before_action` calling `Markets::SettleSealed.call(limit: 10)` on `MarketsController#index`/`#show` and `Studio::MarketsController#index`.
   - On a schedule: add `markets:settle_sealed` to `lib/tasks/markets.rake`, for #23 to run next to `markets:lock_expired`.

## Acceptance criteria
- [ ] A creator can tick one outcome as the real result; ticking two shows a form error
- [ ] After betting closes (by the clock or an early lock), the next feed, show or Studio page view shows the market settled, with payouts in bettors' wallets
- [ ] The sealed outcome never appears in feed or show HTML before settlement
- [ ] RSpec `spec/services/markets/settle_sealed_spec.rb`: settles only sealed markets past their lock, respects `limit`, skips open and already-settled markets, returns the count
- [ ] RSpec `spec/models/market_spec.rb`: at most one sealed outcome, and it belongs to the market
- [ ] RSpec `spec/services/markets/resolve_spec.rb`: refuses a winner other than the sealed outcome
- [ ] RSpec `spec/requests/markets_spec.rb`: no leak in the HTML, and the market settles on page view
- [ ] RSpec: a spec for the `markets:settle_sealed` rake task
- [ ] Cucumber `features/studio/sealed_result.feature`: "A pre-recorded clip settles itself when betting closes". Post through the form with one ticked outcome, add two predictions, `16 minutes pass`, open the feed, then see "Settled" and the winner's new balance.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. #23 adds the scheduled run, and #8 makes the result appear live.
- **Out of scope:** editing the sealed result, proving it was sealed before betting (commit-reveal), auto-locking at a timestamp inside the clip
- **Size:** M
