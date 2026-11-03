---
title: "Add credits to an existing prediction before lock"
labels: ["type: feature", "area: betting-engine", "priority: P3 · backlog"]
---
## Summary
As a bettor who already picked an outcome, I want to add credits to the same pick before betting locks (up to the 100-credit cap), so I can back my call harder as the pool moves instead of being stuck with my first stake.

## Context
- [`Bet`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/bet.rb): one bet per user per market (`one_prediction_per_market` on create, plus the unique index on `bets (user_id, market_id)`); stake `MIN_STAKE..MAX_STAKE` is validated on every save, but `market_must_be_accepting_bets` only on create.
- [`Betting::PlaceBet`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/betting/place_bet.rb) locks the market row, saves the bet, debits via `Wallet#debit!(kind: :stake, market:, bet:)`, and grows pools with `Outcome.update_counters`/`Market.update_counters`.
- [`BetsController`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/bets_controller.rb) only has `create`; `render_card_update` replaces the card, `#wallet-balance`, and `#flash`.
- [`_bet_panel.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_bet_panel.html.erb) shows "You picked X for N credits" for a pending bet, with no actions.
- [`Markets::Resolve`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/resolve.rb) and [`Markets::Cancel`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/cancel.rb) settle on `bet.stake`, so a bigger stake settles correctly as long as every debit is in the ledger.

## Suggested implementation
1. `Betting::IncreaseStake` (new, `app/services/betting/increase_stake.rb`, `initialize(bet:, amount:)`):
```ruby
def perform
  Market.transaction do
    market = @bet.market.lock! # same first lock as PlaceBet, Lock, and Resolve, so they serialize
    @bet.lock!                 # reloads the current stake
    fail!("Betting is closed for this market") unless market.accepting_bets?
    fail!("This prediction is already settled") unless @bet.pending?
    remaining = Bet::MAX_STAKE - @bet.stake
    fail!("You can add 1 to #{remaining} more credits") unless @amount.to_i.between?(1, remaining)
    @bet.update!(stake: @bet.stake + @amount)
    debit(market) # Wallet#debit!(@amount, kind: :stake, market:, bet: @bet); InsufficientCredits -> fail!
    Outcome.update_counters(@bet.outcome_id, pool: @amount)
    Market.update_counters(market.id, total_pool: @amount)
    @bet
  end
end
```
   Fail with "already at the 100-credit cap" when `remaining` is 0. Never touch `bets_count` or the outcome: switching sides is out of scope.
2. Routes: `resources :bets, only: %i[create update]` inside `resources :markets`. `BetsController#update` finds `Current.user.bets.where(market: @market).find(params[:id])` (404 for anyone else's bet), parses `Integer(params[:amount].to_s, exception: false)`, and reuses `create`'s Turbo Stream/HTML branches with "Added 25 credits. You now have 45 on Lands it."
3. `_bet_panel.html.erb`, pending branch, when `phase == :open` and `viewer_bet.stake < Bet::MAX_STAKE`: an "Add credits" `form_with url: market_bet_path(market, viewer_bet), method: :patch, class: "top-up"` with the hidden `context` field and one `<button name="amount" value="…" class="chip">` per `Bet::QUICK_STAKES` amount below the remaining cap, plus the remainder itself ("+30 max"). No JS. Dim it when the countdown marks the card locked: `.clip-card.is-locked .top-up .chip { pointer-events: none; opacity: 0.5; }`, mirroring the bet-form rule.
4. The wallet will list a second "Prediction on “…”" row for the same bet; that's intended (same kind, same bet).

## Acceptance criteria
- [ ] With a pending 20-credit bet, adding 25 makes the stake 45, takes 25 from the balance, adds 25 to the outcome and market pools, leaves `bets_count` alone, and writes a second `stake` entry for the bet
- [ ] Going past 100 total, after lock (early or by the clock), on a settled bet, without enough credits, or with a non-positive amount fails with a clear message and changes nothing
- [ ] Settling a topped-up market pays on the total stake and conserves credits
- [ ] RSpec: `spec/services/betting/increase_stake_spec.rb` (cases above); PATCH examples in `spec/requests/bets_spec.rb` (stream replaces card and balance, other user's bet is 404, guest redirect); a top-up example in `spec/services/markets/resolve_spec.rb`
- [ ] Cucumber `features/betting/add_credits.feature`: "Adding credits to my pick before lock"; "The add-credits chips stop at the 100-credit cap"; "No add-credits option once betting locks"
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Add a top-up race to #28 (Concurrency specs for simultaneous bets and settlements) if it has landed.
- **Out of scope:** switching outcomes, lowering a stake, a separate ledger kind for top-ups.
- **Size:** M
