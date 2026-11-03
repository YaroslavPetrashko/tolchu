---
title: "Feed filters: Closing soon, Sports, Stunts"
labels: ["type: feature", "area: frontend", "area: database", "priority: P3 · backlog"]
---
## Summary
As a viewer I want tabs on the feed (All, Closing soon, Sports, Stunts), so I can jump to markets about to lock or to the kind of clip I like instead of scrolling past everything.

## Context
- [`MarketFeed`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/market_feed.rb) builds three sections from `base` (`Market.includes(:creator, :outcomes, :winning_outcome)`); [`MarketsController#index`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/markets_controller.rb) passes only `viewer`.
- In [`application.css`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/assets/stylesheets/application.css), `.feed` and `.clip-card` are both `calc(100dvh - var(--topbar-h))` tall, assuming nothing sits between the top bar and the feed.
- Markets have no category. The form is [`studio/markets/new.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/studio/markets/new.html.erb); params are permitted in `Studio::MarketsController#market_params`.
- [`db/seeds.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/db/seeds.rb) creates seven markets through its `post_market` helper.

## Suggested implementation
1. Migration (new): `add_column :markets, :category, :string, null: false, default: "other"`, `add_index :markets, :category`, and `add_check_constraint :markets, "category IN ('sports', 'stunts', 'other')", name: "markets_category_check"`.
2. `Market`: `enum :category, { sports: "sports", stunts: "stunts", other: "other" }, default: :other, validate: true`; add `category: "Category"` under `market` in `config/locales/en.yml`.
3. Studio: `form.select :category, Market.categories.keys.map { |key| [ key.humanize, key ] }` in `new.html.erb`; permit `:category`.
4. `MarketFeed.new(viewer:, now:, tab:)` with `TABS = %w[all closing_soon sports stunts]`; anything else means `"all"`.
   - `sports`, `stunts`: `where(category: tab)` on every section.
   - `closing_soon`: only the open section, `accepting_bets(now).where(locks_at: ..(now + 1.hour))`, soonest first; the other sections are empty.
   Apply the filter in `base` today, or on the single ordered scope if #29 (Infinite scroll for the feed) has merged (then also pass `tab` in the next-page `src`).
5. View: `markets/_feed_tabs.html.erb` (new) above `.feed` in `index.html.erb`: `<nav aria-label="Feed filters">` with `link_to` `root_path(tab:)` for each tab, `is-active` and `aria-current="page"` on the current one. CSS: add `--tabs-h: 44px` and make `.feed` and `.clip-card` `calc(100dvh - var(--topbar-h) - var(--tabs-h))` so a card still fills exactly one screen. Per-tab empty state, e.g. "No sports clips right now", with a link back to All.
6. Seeds: pass `category:` through `post_market`. Sports: the pull-up jumper, the drive to the rim, the show-jumping round. Stunts: the backflip, board flip, keepy-uppy, and pool jump. Production rows get the default `other`; reseed with #6 (Add a demo reset task for presentations) or set the seven demo markets with a one-off `heroku run bin/rails runner` (paste the command in the PR).

## Acceptance criteria
- [ ] Creators pick a category (default Other); invalid values are rejected by the model and the database
- [ ] `?tab=sports` and `?tab=stunts` show only that category in the usual order; `?tab=closing_soon` shows only markets taking bets that lock within the hour; unknown tabs show All
- [ ] The current tab has `aria-current="page"`; cards still fill exactly one screen
- [ ] RSpec: `spec/models/market_spec.rb` (enum, default), `spec/models/market_feed_spec.rb` (each tab, the exactly-one-hour boundary), `spec/requests/markets_spec.rb` (`?tab=` filtering, unknown tab), `spec/requests/studio/markets_spec.rb` (category saved)
- [ ] Cucumber `features/feed/filter_feed.feature`: "Showing only sports clips" (new step `{string} posted {string} in {string}` in `market_steps.rb`); "Closing soon lists markets that lock within the hour" (reuses "that locks in N minutes"); plus "Posting a market in a category" in `create_market.feature`
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. #34 (Follow creators and a Following feed) adds a Following tab on top of this.
- **Out of scope:** creator-defined tags, search, remembering the last tab.
- **Size:** M
