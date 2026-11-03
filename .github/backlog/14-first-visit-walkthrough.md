---
title: "First-visit walkthrough of pools and payouts"
labels: ["type: feature", "area: frontend", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
As a casual fan opening Tolchu for the first time, I want a short walkthrough on the first clip so that I understand the freeze, the pick, and the shared pool before I stake anything. Real-user testers will mostly be people who have never seen a parimutuel pool.

## Context
- The feed ([`app/views/markets/index.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/index.html.erb)) renders [`MarketFeed`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/market_feed.rb) (open markets first) with [`markets/_market.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_market.html.erb). Each card has `.clip-card__media`, the `.outcomes` list, and `.clip-card__pool`.
- The only explanation today is [`pages/how_it_works.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/pages/how_it_works.html.erb), linked from the nav.
- `users` has no onboarding state ([`db/schema.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/db/schema.rb)). New Stimulus controllers register automatically ([`config/importmap.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/importmap.rb)).

## Suggested implementation
1. Migration: `add_column :users, :onboarded_at, :datetime` (no backfill; existing accounts see it once).
2. Route `resource :onboarding, only: :update` and a new `OnboardingsController#update`: set `onboarded_at` if nil, then `turbo_stream.remove("onboarding")`, or `redirect_to root_path, status: :see_other` for HTML.
3. New partial `markets/_onboarding.html.erb`, rendered at the end of `markets/index.html.erb` only when `@feed.markets.first&.accepting_bets?` and the viewer is a guest or has `onboarded_at: nil`. Use a native `<dialog id="onboarding" aria-labelledby="…">` with three `<section>`s ("Watch until it freezes", "Pick what happens next", "Win from the pool"; steps 2 and 3 start `hidden`), Next and Skip buttons, and a "How payouts work" link to `how_it_works_path` on the last step. Signed-in users finish with `button_to "Got it", onboarding_path, method: :patch`; guests get a `type="button"`.
4. New `app/javascript/controllers/onboarding_controller.js`:
   - `connect()`: if `localStorage["tolchu:onboarded"]` is set (read inside `try/catch`), silently submit the PATCH form when signed in (a guest who dismissed it, then signed up) and stop. Otherwise call `this.element.showModal()`, which gives dialog semantics, `aria-modal` behavior, an inert page, and Escape via the `cancel` event.
   - Each step spotlights its target in the first card (`.clip-card__media`, `.outcomes`, `.clip-card__pool`) with a class that adds a large `box-shadow`, and moves focus to the step heading.
   - `finish()` (Got it, Skip, Escape): set the localStorage key, `close()` (focus returns to the feed), and `requestSubmit()` the PATCH form when signed in.
5. CSS: transparent `dialog::backdrop` (the spotlight dims the page); no transitions under `prefers-reduced-motion: reduce`.

Gotchas:
- Keep "Place bet" out of the copy: `spec/requests/markets_spec.rb` and `browse_feed.feature` assert guests see no "Place bet". Don't name the link "How it works": `how_it_works.feature` clicks the nav link by that text, and two matches are ambiguous.
- rack_test treats `[hidden]` as invisible but a closed `<dialog>` as visible, so Cucumber can read step 1 and press "Got it" without JavaScript.

## Acceptance criteria
- [ ] Guests and new accounts see the 3-step walkthrough on the first open card; Got it, Skip, and Escape close it. It isn't rendered when the first card is locked or settled.
- [ ] Guests don't see it again in the same browser; signed-in users never see it again once `onboarded_at` is set.
- [ ] Keyboard only: focus starts in the dialog, Tab stays inside, Escape closes it, focus returns to the feed.
- [ ] RSpec: `spec/requests/onboardings_spec.rb` (PATCH sets `onboarded_at` once, requires sign-in, turbo_stream removes `#onboarding`); `spec/requests/markets_spec.rb` (dialog present for a new user, absent when onboarded or when the first card is locked).
- [ ] Cucumber `features/feed/onboarding.feature`: a new fan sees "Watch until it freezes" on the feed, presses "Got it", and the walkthrough is gone on the next visit.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Testing focus, Escape, and localStorage in a real browser needs the JS driver from #12 (Browser-level Cucumber scenarios for the clip player, countdown, and stake estimate). #21 can add an `onboarding_completed` event.
- **Out of scope:** per-market tooltips, replaying the walkthrough later, changes to the how-it-works page.
- **Size:** M (1–2 days)
