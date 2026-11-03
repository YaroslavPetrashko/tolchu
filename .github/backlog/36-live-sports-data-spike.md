---
title: "Research live sports data feeds for automatic locks"
labels: ["type: spike", "area: betting-engine", "priority: P3 · backlog"]
---
## Summary
The proposal promises "live data feeds that lock wagers fractions of a second before a play begins". Today every lock is a creator's button or the `locks_at` clock. In at most two days, find out whether a data provider can drive locks and results for live games, what it costs, and whether its license allows a betting-style product; record the answer as a decision.

## Context
- [`Markets::Lock`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/lock.rb) takes `now:` and sets `locked_at = locks_at = now`, but refuses once betting has closed, so it can't lock retroactively. [`Markets::Resolve`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/resolve.rb) takes `winning_outcome_id:` and settles exactly once.
- `bets.created_at` is the only record of when a bet arrived ([`db/schema.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/db/schema.rb)).
- [`Market`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/market.rb) is built around a clip (`video_url`, `freeze_at`); nothing models a live game, a provider event id, or a machine-readable outcome.
- Infrastructure: one Basic web dyno, no worker ([`Procfile`](https://github.com/YaroslavPetrashko/tolchu/blob/main/Procfile)), Heroku Scheduler runs at most every 10 minutes, about $300 of credits.

## Suggested implementation
1. **Compare providers** in one table: Sportradar, SportsDataIO, API-Sports (API-Football and siblings), TheSportsDB, MySportsFeeds. Columns: sports; granularity (play-by-play vs. score/event level); delivery (push stream, webhook, or polling) and delay after the real event; free tier or trial and price at our scale; license terms for betting use, and whether play-money predictions count. Many terms forbid wagering use without a commercial license: quote the clause, link it, note the date checked, and ask sales in writing when unclear.
2. **Map events onto our services:**
   - *Lock at play start:* the play-start event (or the last pre-play event, such as a free throw being awarded) calls `Markets::Lock.call(market:, now: event_time)`. Events arrive after they happen, so bets with `created_at >= event_time` must be refunded through `Wallet` and taken out of the pools; that "void late bets" step doesn't exist yet.
   - *Result:* map the result event to an outcome (e.g. `markets.external_event_id`, `outcomes.external_code`) and call `Markets::Resolve`. A market settles once, so decide how long to wait for stat corrections.
   - *Broadcast delay:* a viewer's video lags the feed by roughly 5–30 s, so locking on what's on screen lets anyone with a faster source bet on a play that already happened. Locks must use the feed's event time, never the video.
   - *Ingestion:* push needs a signed webhook endpoint on the web dyno; polling needs a `worker:` process (extra dyno cost).
3. **Write `docs/decisions/0002-live-data.md`** (`0001` is expected from #13; create `docs/decisions/` if it doesn't exist yet): context, options table, recommendation ("not yet" is valid if licenses rule it out), consequences, and a prototype plan: one sport, one provider trial, a recorded game feed replayed against a local market, measuring event-to-lock delay and how many bets would be voided.

## Acceptance criteria
- [ ] `docs/decisions/0002-live-data.md` merged, comparing all five providers on latency, push vs. poll, pricing or free tier, and license terms, with links and access dates
- [ ] A per-provider answer on whether a play-money product may use the data
- [ ] Lock mapping, late-bet voiding, result mapping, and broadcast delay described against the current services
- [ ] A recommendation and a prototype plan with monthly cost and a success metric (e.g. lock recorded within 1 s of the play-start event)
- [ ] No application code changes
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. If #13 (Decide between Supabase and Heroku Postgres) has already written a decision record, match its format.
- **Out of scope:** building the integration, streaming live video, real-money compliance.
- **Size:** M (time-boxed to two days)
