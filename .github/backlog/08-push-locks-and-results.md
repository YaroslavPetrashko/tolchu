---
title: "Push locks and results to open feeds in real time"
labels: ["type: feature", "area: frontend", "area: backend", "priority: P1 · iteration 2"]
milestone: "Iteration 2"
---
## Summary
As a fan with the feed open, I want to see the creator lock a clip the moment it happens ("Betting closed"). When the result is declared, the clip should play to the end and my card should show "You called it! … paid 190 credits" with my new balance, all without reloading. That moment is the payoff of the product.

## Context
- **State changes.** These go through [`Markets::Lock`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/lock.rb), [`Markets::Resolve`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/resolve.rb) and [`Markets::Cancel`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/cancel.rb), each using `Market.transaction` and `update!`. [`Markets::LockExpired`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/lock_expired.rb) uses `update_all`, so model callbacks never fire.
- **Results are personal.** [`_bet_panel.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_bet_panel.html.erb) renders won/lost/refunded text per viewer, and `#wallet-balance` in [`_nav.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/layouts/_nav.html.erb) is per viewer too. A single rendered fragment can't serve everyone; each browser must re-fetch its own page.
- **Client-side clip and countdown state.**
  - [`clip_controller.js`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/javascript/controllers/clip_controller.js) freezes at `freezeAt` until `data-clip-revealed-value` (`phase == :resolved`) is true. It stores the frozen state as the `is-frozen` class.
  - [`countdown_controller.js`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/javascript/controllers/countdown_controller.js) ignores later changes to `live`.
- **Turbo support.** The layout yields `:head`, which `turbo_refreshes_with` needs, and turbo-rails 2.0.23 ships Turbo 8 (morphing, `broadcast_refresh_to`).
- **From #7.** Guests can connect, and every card has `turbo_stream_from market`.

## Suggested implementation
1. **Morph on refresh.** In `markets/index.html.erb` and `markets/show.html.erb` add `<% turbo_refreshes_with method: :morph, scroll: :preserve %>`. The feed scrolls inside `.feed`, not the window, so give `.feed` an `id` so morphing keeps that node and its `scrollTop`.
2. **Broadcast a refresh after each successful service.** In `Lock`, `Resolve` and `Cancel`, after the transaction commits, call `Turbo::StreamsChannel.broadcast_refresh_to(market)`. Use the same `ActiveRecord.after_all_transactions_commit` wrapper #7 uses in `PlaceBet`.
   - **`LockExpired`:** load the expired markets, `update_all` by their ids (keep the `open` condition), then refresh each one.
   - The payload is a tiny `<turbo-stream action="refresh">`. It also reaches the web dyno from a rake task on a one-off dyno, through Postgres NOTIFY.
3. **Keep videos playing.** Give `<video>` `id: dom_id(market, :video)` and `data-turbo-permanent`. Turbo then leaves the playing video alone during morphs and during the stream replaces from #7 and `BetsController`.
4. **`clip_controller.js`.** Track frozen state in `this.frozen` instead of the class: morphing resets the article's `class` to the server's and drops `is-frozen`. Re-apply the class on the document's `turbo:morph` event. Add `revealedValueChanged()`: when revealed and frozen, unfreeze and `play()` so the ending runs.
5. **`countdown_controller.js`.** Add `liveValueChanged()` to clear the timer when `live` turns false. Otherwise, after an early lock, it keeps overwriting the server's "Betting closed" label with "Locks in …".
6. **`stake_controller.js`.** A refresh triggered by another market must not wipe a half-filled bet form. Handle `turbo:before-morph-element` on its own form and call `preventDefault()` while an outcome is selected, unless `event.detail.newElement` is missing (the form is being removed because this market locked).

## Acceptance criteria
- [ ] Creator locks early: open feeds show "Locked" and drop the bet form within about 1 s, and the countdown stops
- [ ] Result declared: frozen clips play to the end, the bettor's card shows "You called it! …" or "You picked … and lost …", and `#wallet-balance` updates, all without a manual reload
- [ ] Cancellations and `markets:lock_expired` locks also appear live
- [ ] Playing videos don't restart, the feed keeps its scroll position, and other cards' half-filled forms survive
- [ ] RSpec `spec/services/markets/{lock,resolve,cancel,lock_expired}_spec.rb`: success passes `have_broadcasted_to(market.to_gid_param).with(a_string_including('action="refresh"'))`; failures broadcast nothing
- [ ] RSpec `spec/requests/markets_spec.rb`: feed and show include `<meta name="turbo-refresh-method" content="morph">`
- [ ] Cucumber (needs #12's driver): `@javascript` "My result shows up while I'm watching the feed" (on the feed, the market is settled, then the card and balance update)
- [ ] `bin/ci` passes

## Notes
- **Depends on:** #7 (Stream live pool and odds updates to every viewer). The browser scenario needs #12.
- **Out of scope:** notifying bettors who aren't on the page (#15 Notify bettors when their prediction settles), new markets appearing in open feeds, live Studio and Wallet pages
- **Size:** M
