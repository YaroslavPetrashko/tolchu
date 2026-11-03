---
title: "Infinite scroll for the feed"
labels: ["type: feature", "area: frontend", "area: backend", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
As a viewer I want the feed to load more clips as I scroll, so the first screen is fast and older results stay reachable. Today everything renders in one response and history stops at 12 results, which gets worse as real users post during the final demo.

## Context
- [`MarketFeed#markets`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/market_feed.rb) concatenates three queries into an array (open by `locks_at, id`; awaiting a result by `locks_at desc, id desc`; resolved by `resolved_at desc, id desc`, capped at `RECENT_RESULTS_LIMIT = 12`), skipping cancelled markets. It can't be paged.
- `MarketFeed#bet_for` loads the viewer's bets for exactly the markets returned, so it becomes per page for free.
- [`markets/index.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/index.html.erb) renders all cards inside `.feed` (the scroll-snap container) and ends with `.feed-end`.
- Stimulus connects `clip` and `countdown` on cards added later; `BetsController` replaces a card by `dom_id(market)` wherever it sits.

## Suggested implementation
1. **One ordered query.** Rank the phase in SQL with a bound `now`, then apply each section's keys. Postgres can't use a select alias inside ORDER BY expressions, so rank in a subquery:
```ruby
PER_PAGE = 10
RANK = "CASE WHEN status = 'open' AND locks_at > :now THEN 0 WHEN status IN ('open', 'locked') THEN 1 ELSE 2 END".freeze
ORDER = <<~SQL.squish.freeze
  phase_rank, CASE WHEN phase_rank = 0 THEN locks_at END, CASE WHEN phase_rank = 0 THEN id END,
  CASE WHEN phase_rank = 1 THEN locks_at END DESC, CASE WHEN phase_rank = 2 THEN resolved_at END DESC, id DESC
SQL

def ordered
  ranked = Market.where.not(status: :cancelled).select(Market.sanitize_sql_array([ "markets.*, #{RANK} AS phase_rank", { now: } ]))
  Market.from(ranked, :markets).includes(:creator, :outcomes, :winning_outcome).order(Arel.sql(ORDER))
end
```
2. **Paging.** `MarketFeed.new(viewer:, page:, now:)` loads `ordered.offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1)`; `markets` returns the first `PER_PAGE`, `next_page` is `page + 1` when the extra row exists. Delete `RECENT_RESULTS_LIMIT`.
3. **Stable ranks.** A market that locks between page loads would switch sections and repeat or vanish. Carry page 1's clock: next-page URLs include `as_of: feed.now.iso8601(6)`; `MarketsController#index` parses it with `Time.zone.iso8601` (fallback `Time.current`) and clamps `page` to ≥ 1.
4. **Views.** Move the card loop into `markets/_feed_page.html.erb` (new). It ends with `.feed-end` on the last page, otherwise with
   `turbo_frame_tag "feed_page", feed.next_page, src: markets_path(page: feed.next_page, as_of: …), loading: :lazy, target: "_top"`
   around a "Loading more clips…" placeholder. `index.html.erb` keeps `.feed` and renders the partial directly for page 1, or inside `turbo_frame_tag "feed_page", @feed.page, target: "_top"` for later pages (turbo-rails answers frame requests with its minimal `turbo_rails/frame` layout). Show the empty state only when page 1 is empty.
5. **Gotchas.** Without `target: "_top"`, the question link, "Sign in to predict", and "Manage it in Studio" would load inside the frame and fail. Add `.feed turbo-frame { display: block; }` (never `display: contents`: the lazy loader observes the frame's own box).

## Acceptance criteria
- [ ] With 25 live markets the first response has 10 cards and a lazy frame; scrolling to it appends the next 10, which autoplay and count down
- [ ] Order across pages matches today's three sections; cancelled markets never appear; no card appears twice
- [ ] Betting on a page-3 card updates that card and the balance in place
- [ ] RSpec: `spec/models/market_feed_spec.rb` keeps the ordering example, replaces the `RECENT_RESULTS_LIMIT` one, and adds paging (`next_page`, last page, `as_of`); `spec/requests/markets_spec.rb` checks page 1 has `id="feed_page_2"` with `loading="lazy"`, and `GET /markets?page=2` with a `Turbo-Frame: feed_page_2` header returns only page-2 cards
- [ ] Cucumber: none (rack_test can't scroll); browser coverage comes with #12 (Browser-level Cucumber scenarios for the clip player, countdown, and stake estimate)
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. #33 (Feed filters: Closing soon, Sports, Stunts) and #34 (Follow creators and a Following feed) also change `MarketFeed`; whichever lands later carries `tab` into the frame `src`.
- **Out of scope:** keyset pagination, restoring scroll position after Back.
- **Size:** M
