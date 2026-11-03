---
title: "PostHog product analytics for the betting funnel"
labels: ["type: feature", "area: analytics", "area: frontend", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
As the team, we want product analytics on the betting funnel so that, during real-user testing, we can see where people stop between watching a clip and placing a bet, instead of guessing from interviews.

## Context
- Client behavior lives in Stimulus: [`clip_controller.js`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/javascript/controllers/clip_controller.js) (`play()` from an IntersectionObserver, `freeze()`) and [`stake_controller.js`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/javascript/controllers/stake_controller.js) (`pick()` for chips, `update()` on the form's `change`/`input`).
- Server outcomes: [`BetsController#create`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/bets_controller.rb) (`Betting::PlaceBet` result) and [`Studio::MarketsController`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/studio/markets_controller.rb) (`create`, `resolve`, `cancel`).
- No CSP is configured ([`content_security_policy.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/initializers/content_security_policy.rb) is commented out), so PostHog's snippet and CDN load without changes.

## Suggested implementation
1. Create a PostHog Cloud US project and set `POSTHOG_KEY` on the `tolchu` app only. Dev, test, and CI stay silent unless someone sets it locally.
2. Loader: new `layouts/_posthog.html.erb` with PostHog's official HTML snippet, rendered in `<head>` of `application.html.erb` only when `ENV["POSTHOG_KEY"].present?`. We pick the snippet over `bin/importmap pin posthog-js` because nothing loads when the key is absent and calls queue until the library arrives. The snippet is identical on every page, so Turbo runs it once.
   ```js
   posthog.init("<%= ENV["POSTHOG_KEY"] %>", {
     api_host: "https://us.i.posthog.com",
     defaults: "2026-08-30",
     capture_pageview: "history_change", // Turbo Drive visits are history changes
     person_profiles: "identified_only",
     session_recording: { maskAllInputs: true }
   })
   ```
3. New `analytics_controller.js` on `<body>` with `data-analytics-user-id-value="<%= Current.user&.id %>"`: `connect()` calls `window.posthog?.identify(String(id))` (user id only, never email or username), and a `reset` action wired to both "Sign out" buttons ([`_nav.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/layouts/_nav.html.erb), [`wallets/show.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/wallets/show.html.erb)) calls `posthog.reset()`.
4. Client events, each via `window.posthog?.capture(...)` with a new `marketId` value on the card and the bet form:
   - `clip_viewed`: first intersection per connect; `clip_frozen`: first `freeze()` per connect (it can fire several times per freeze).
   - `outcome_selected`: a `change` whose target is `outcome_id`; `stake_chip_used`: in `pick()`, with the amount.
5. Server: add `gem "posthog-ruby"` and a new `app/models/analytics.rb` whose `Analytics.capture(user, event, **properties)` sends `distinct_id: user.id.to_s` through a memoized `PostHog::Client.new(api_key: ENV["POSTHOG_KEY"], host: "https://us.i.posthog.com", on_error: …)`, and returns nil when the key is missing. Call it in controllers after the service returns, never inside a transaction:
   - `bet_placed` (market_id, outcome_id, stake) and `bet_rejected` (market_id, `reason: result.error.gsub(/\d+/, "N")` so reasons group cleanly)
   - `market_created` (market_id, outcome count, betting window) and `market_settled` (resolved or cancelled, refunded, total_pool, bets_count)
6. In PostHog: a funnel insight `clip_viewed` → `outcome_selected` → `bet_placed` (1-hour window) on a "Real-user testing" dashboard; turn on session replay. Document `POSTHOG_KEY` in the README.

## Acceptance criteria
- [ ] With the key set, all six events reach PostHog's activity view with `distinct_id` equal to the user id (guests stay anonymous until they sign in); no email or username appears in any event.
- [ ] Without the key, no snippet is rendered and `Analytics.capture` does nothing (the test suite makes no network calls).
- [ ] The funnel insight is saved, and replays show inputs masked.
- [ ] RSpec: `spec/models/analytics_spec.rb` (no-op without a key; payload with a stubbed client); `spec/requests/bets_spec.rb` and `spec/requests/studio/markets_spec.rb` assert the `Analytics.capture` calls; a request spec that the snippet renders only when `ENV["POSTHOG_KEY"]` is stubbed.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Verifying the client events in a browser needs #12 (Browser-level Cucumber scenarios for the clip player, countdown, and stake estimate). #14 (First-visit walkthrough of pools and payouts) can add an `onboarding_completed` event; #24 follows the same "user id only" rule.
- **Out of scope:** feature flags, experiments, surveys, a cookie banner.
- **Size:** M (1–2 days)
