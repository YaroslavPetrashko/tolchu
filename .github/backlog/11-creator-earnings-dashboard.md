---
title: "Creator earnings dashboard"
labels: ["type: feature", "area: creator-tools", "area: frontend", "priority: P1 · iteration 2"]
milestone: "Iteration 2"
---
## Summary
As a creator, I want one page showing what I've earned, in total and per market, with the reason behind each number. Seeing that an evenly split crowd pays more should encourage creators to keep posting contested clips.

## Context
- **Where rewards are recorded.** [`Markets::Resolve`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/resolve.rb) pays the creator's share as a `LedgerEntry` of kind `creator_reward` ([`ledger_entry.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/ledger_entry.rb)) and caches it on `markets.creator_reward`. `markets.house_take` stores the house's net take.
- **The formula** lives in [`Parimutuel`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/parimutuel.rb):
  - `rake_for(total_pool:, losing_pool:)` = min(⌊5% of the pool⌋, the losing pool)
  - `creator_reward_for(rake:, contest_score:)` = ⌊rake × ½ × contest score⌋
  - `contest_score(pools)` is 0 when one outcome holds all the money and 1 when the pool is split evenly; `Market#contest_score` applies it to the market's outcome pools.
- **What the Studio shows today.** [`studio/markets/_market.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/studio/markets/_market.html.erb) shows "Your reward" and "Contest score" for each resolved market. There are no totals and no explanation.
- **Scoping.** [`Studio::MarketsController`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/studio/markets_controller.rb) scopes everything to `Current.user.created_markets`.

## Suggested implementation
1. **Route.** Inside `namespace :studio` in [`config/routes.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/routes.rb), add `resource :earnings, only: :show`. That gives `GET /studio/earnings` and `studio_earnings_path`.
2. **Controller** `Studio::EarningsController#show` (new; authentication is required by default):
   - `@total = Current.user.ledger_entries.creator_reward.sum(:amount)`. The ledger is the source of truth.
   - `@markets = Current.user.created_markets.resolved.includes(:outcomes, :winning_outcome).order(resolved_at: :desc, id: :desc)`
3. **`Market#rake`** (new): `0` when `refunded?`, otherwise `Parimutuel.rake_for(total_pool:, losing_pool: total_pool - winning_outcome.pool)`. This lets the page show the fee each reward came from.
4. **View** `studio/earnings/show.html.erb` (new):
   - Summary tiles in the style of `.wallet-stats`: total earned, settled markets, average contest score.
   - A `.data-table` with columns Question (linked), Pool, Fee, Contest score, Your reward. Draw the contest score as a CSS-only bar, e.g. `<span class="meter" style="--value: 62%">`, using the same gradient trick as `.outcome`. No chart library. No-contest refunds show "No contest" and 0.
   - The explainer: "Your reward = fee × 50% × contest score, rounded down. The fee is 5% of the pool, capped at what the losing side staked."
   - An empty state linking to "New market".
5. **Studio link.** In the Studio header ([`studio/markets/index.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/studio/markets/index.html.erb)), link to the page with a one-line total, e.g. "You've earned 12 credits · See earnings".
6. **Cucumber plumbing.** Add `"my earnings"` to `path_to` in [`features/support/paths.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/features/support/paths.rb) and to the `{page}` regexp in [`features/support/parameter_types.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/features/support/parameter_types.rb).

## Acceptance criteria
- [ ] `/studio/earnings` shows the ledger total, one row per resolved market I created (and none from other creators), and the formula explainer
- [ ] The rows' rewards add up to the ledger total
- [ ] Guests are redirected to sign in
- [ ] RSpec `spec/requests/studio/earnings_spec.rb` (new): authentication, own markets only, totals, empty state
- [ ] RSpec `spec/models/market_spec.rb`: `#rake`, and for a resolved market `creator_reward == Parimutuel.creator_reward_for(rake:, contest_score:)`
- [ ] Cucumber `features/studio/earnings.feature`: "Seeing what I earned and why". Two 100-credit predictions on opposite sides, then settlement, should show a 5-credit reward and a 100% contest score.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing
- **Out of scope:** projected rewards for open markets, chart libraries, earnings history for anything other than resolved markets
- **Size:** M
