---
title: "Weekly leaderboard of top predictors"
labels: ["type: feature", "area: frontend", "area: backend", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
As a competitive fan, I want a weekly ranking of the best predictors, so I have a reason to come back and a fresh shot every Monday. A weekly reset keeps first-time testers from facing an all-time board they can never climb.

## Context
- Settled bets carry `status` (won/lost/refunded) and `payout` ([`app/models/bet.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/bet.rb)). `markets.resolved_at` is set by [`Markets::Resolve`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/resolve.rb), which accepts `now:` (useful in specs). Cancelled markets get `cancelled_at`, never `resolved_at`.
- The app time zone is Eastern ([`config/application.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/application.rb)) and `beginning_of_week` is the Rails default, Monday.
- Production caches in `:memory_store` on one dyno ([`config/environments/production.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/environments/production.rb)); tests use `:null_store` ([`config/environments/test.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/environments/test.rb)).

## Suggested implementation
1. Route `resource :leaderboard, only: :show` and a new `LeaderboardsController#show` with `allow_unauthenticated_access`. Add a "Leaderboard" link to `.topbar__links` in [`layouts/_nav.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/layouts/_nav.html.erb).
2. New PORO `app/models/leaderboard.rb` with `initialize(now: Time.current)` storing `@week = now.all_week` (Monday 00:00 to Sunday 23:59:59 Eastern) and:
   ```ruby
   def rows
     Rails.cache.fetch([ "leaderboard", @week.begin.to_date ], expires_in: 5.minutes) do
       Bet.joins(:market, :user)
          .where(markets: { resolved_at: @week }, status: %w[won lost])
          .group("users.id", "users.username")
          .order(Arel.sql("SUM(bets.payout - bets.stake) DESC, COUNT(*) FILTER (WHERE bets.status = 'won') DESC, users.username"))
          .limit(20)
          .pluck("users.username", Arel.sql("SUM(bets.payout - bets.stake)"),
                 Arel.sql("COUNT(*) FILTER (WHERE bets.status = 'won')"), Arel.sql("COUNT(*)"))
     end
   end
   ```
   - Filtering on `won`/`lost` drops refunded bets (no-contest pools) and pending ones; cancelled markets never match `resolved_at`. Creator rewards don't count.
   - Cache plain arrays from `pluck`, never relations. Keying by the week's Monday makes the board reset itself.
   - Username is the final tie-break so the order is deterministic.
3. View `leaderboards/show.html.erb`: "Week of Nov 9" heading, a `.data-table` with rank, username, net (`signed_credits`), wins, and settled predictions, plus an empty state before anything settles this week. Highlight the signed-in user's row if present.

Time-travel specs (`travel_to` plus `Markets::Resolve.call(…, now:)`):
- a market resolved Sunday Nov 8 23:59 Eastern counts for the previous week, one resolved Monday Nov 9 00:01 counts for the new one;
- Monday 02:00 UTC is still Sunday 21:00 Eastern, so it belongs to the previous week.

## Acceptance criteria
- [ ] `/leaderboard` lists the top 20 users by net profit (payout minus stake) on markets resolved this week, Monday to Sunday Eastern, with ties broken by wins.
- [ ] Refunded bets, pending bets, and cancelled markets don't affect the ranking.
- [ ] Results are cached for 5 minutes per week.
- [ ] RSpec: `spec/models/leaderboard_spec.rb` (week boundaries and the UTC offset above, tie-break by wins, 20-row limit, refunds excluded); `spec/requests/leaderboards_spec.rb` (guests get 200, empty state).
- [ ] Cucumber `features/feed/leaderboard.feature`: after markets settle this week, the bettor with the higher net profit is listed first ("alice" before "bob"), and "carol", whose only bet was refunded, is not listed.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Link usernames to profiles once #16 (Public profiles with prediction stats) lands. #15 and #20 also edit `_nav.html.erb`, so expect a small merge.
- **Out of scope:** an all-time board, showing your own rank outside the top 20, prizes or badges.
- **Size:** M (1–2 days)
