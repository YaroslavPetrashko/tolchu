---
title: "Stream live pool and odds updates to every viewer"
labels: ["type: feature", "area: frontend", "area: backend", "priority: P1 · iteration 2"]
milestone: "Iteration 2"
---
## Summary
As a fan watching a clip, I want the pool total, prediction count, share bars and odds to move as other people bet. The market should feel live, and the payout estimate I see before committing credits should be current.

## Context
- **How bets update pools.** [`Betting::PlaceBet`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/betting/place_bet.rb) bumps `outcomes.pool` and `markets.total_pool` with `update_counters` inside `Market.transaction`, then calls `@market.reload`.
- **Who sees it today.** Only the bettor's own card updates. [`BetsController#render_card_update`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/bets_controller.rb) replaces `dom_id(market)`.
- **The card is viewer-specific, so we can't broadcast the whole thing.**
  - [`_bet_panel.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_bet_panel.html.erb) shows one of: the bet form, "You picked …", "Sign in to predict", or the creator note.
  - [`_outcomes.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_outcomes.html.erb) adds radios and `outcome--picked`.
- **What is safe to share with every viewer.**
  - The pool line `p.clip-card__pool` in [`_market.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_market.html.erb).
  - Each outcome's `.outcome__stats` (share and odds).
  - The share bar is a `--share` variable on the `<li>`, painted by `.outcome`'s gradient in [`application.css`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/assets/stylesheets/application.css).
- **Stale estimate.** [`stake_controller.js`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/javascript/controllers/stake_controller.js) estimates from `data-stake-pools-value` / `data-stake-total-pool-value`, which go stale.
- **Cable setup.**
  - [`config/cable.yml`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/cable.yml) uses `postgresql` in production. That means NOTIFY, so each payload must stay under 8,000 bytes, plus one extra DB connection per dyno. Tests use the `test` adapter.
  - [`ApplicationCable::Connection`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/channels/application_cable/connection.rb) rejects guests.

## Suggested implementation
1. **Allow guests to connect.** `connect` should just set `self.current_user = Session.find_by(id: cookies.signed[:session_id])&.user`, without rejecting. Turbo stream names are signed, so a guest can only subscribe to streams the server rendered for them.
2. **Add two new partials** and render them from the existing views:
   - `markets/_pool.html.erb`, with `id: dom_id(market, :pool)`.
   - `markets/_outcome_stats.html.erb`, with `id: dom_id(outcome, :stats)` and `data: { stake_target: "pool", outcome_id:, pool: }`.
   - Move the share bar into the stats partial as `<span class="outcome__bar" style="--share: …">`, positioned behind the row. CSS: `.outcome { isolation: isolate }` and `.outcome__bar { position: absolute; inset: 0 auto 0 0; width: var(--share); z-index: -1 }`. Drop `style` from the `<li>` and adapt `.outcome--winner`.
3. **Subscribe.** Add `<%= turbo_stream_from market %>` inside the card in `_market.html.erb`. The feed, the show page and the bet response then all subscribe.
4. **Broadcast one small message per bet** from `PlaceBet#perform`, after the transaction block (next to `@market.reload`), never inside it:

```ruby
ActiveRecord.after_all_transactions_commit do # also waits for outer transactions, e.g. db/seeds.rb
  Turbo::StreamsChannel.broadcast_render_to(@market, partial: "markets/live_stats", locals: { market: @market })
end
```
   - Add `markets/_live_stats.turbo_stream.erb` (new). It emits `turbo_stream.replace` for `dom_id(market, :pool)` and for each `dom_id(outcome, :stats)`.
   - Use `replace`, not `update`, so `data-pool` is refreshed too.
   - It renders through `ApplicationController.render`, where `Current.user` is nil. Keep it free of viewer state.
5. **Update `stake_controller.js`.**
   - Drop the `pools`/`totalPool` values and their data attributes in `_bet_panel`.
   - Read pools from `this.poolTargets` (`dataset.outcomeId`, `dataset.pool`); the total is their sum.
   - Call `update()` from `poolTargetConnected()`, which fires whenever a broadcast swaps in fresh stats.

## Acceptance criteria
- [ ] With two browsers on a review app, a bet in one updates the other's pool line, bars and odds within about 1 s, with no reload, for both guests and signed-in users
- [ ] The observer's selected outcome and typed stake survive the update, and the estimate recalculates
- [ ] RSpec `spec/services/betting/place_bet_spec.rb`:
  - a bet passes `have_broadcasted_to(market.to_gid_param)` and targets the pool and stats ids
  - a rejected bet broadcasts nothing
  - the payload contains no `outcome_id` radio, "You picked" or "Place bet"
- [ ] RSpec `spec/channels/application_cable/connection_spec.rb` (new): guests connect with `current_user` nil, and a session cookie identifies the user
- [ ] RSpec `spec/requests/markets_spec.rb`: the feed and show pages render `turbo-cable-stream-source` and the stable ids
- [ ] Cucumber (once #12 lands): `@javascript` "Another fan's prediction updates the pool on my screen"
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. The browser scenario needs #12.
- **Out of scope:** locks and results (#8 Push locks and results to open feeds in real time), the show page's "Pool breakdown" table, Redis
- **Size:** M
