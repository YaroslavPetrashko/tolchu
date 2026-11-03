---
title: "Rate-limit bet placement"
labels: ["type: chore", "area: backend", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
Cap how fast one account can submit bets, so a script or a stuck double-tap can't hammer `BetsController#create`, which takes row locks on every request. Do it before real-user testing puts the app on the open internet.

## Context
- [`BetsController#create`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/bets_controller.rb) runs [`Betting::PlaceBet`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/betting/place_bet.rb), which calls `@market.lock!` (and locks the user row through `Wallet`) on every request, including ones that end in a validation error.
- [`SessionsController`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/sessions_controller.rb) and `RegistrationsController` already use Rails 8's `rate_limit` with a custom `with:`. Without one, Rails 8.1 raises `ActionController::TooManyRequests` and renders a bare 429.
- `rate_limit` keeps its counters in the controller's `cache_store`, captured when the class loads. That is `:memory_store` in [`production.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/environments/production.rb) (fine on one dyno) and `:null_store` in [`test.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/environments/test.rb), whose `increment` returns nil, so limits never trigger in tests.

## Suggested implementation
1. In `BetsController`, declare the limit after `before_action :set_market` (callbacks run in order, and the handler needs `@market` for `return_path`):
   ```ruby
   rate_limit to: 20, within: 1.minute, only: :create, by: -> { Current.user.id }, with: :too_many_bets
   ```
   `require_authentication` from `ApplicationController` runs first, so `Current.user` is always set. Keying by user rather than IP keeps everyone on the same campus Wi-Fi from sharing one bucket.
2. Add a private handler that mirrors the existing failure branch:
   ```ruby
   def too_many_bets
     message = "You're placing bets too fast. Wait a minute and try again."
     flash.now[:alert] = message
     respond_to do |format|
       format.turbo_stream { render turbo_stream: turbo_stream.update("flash", partial: "layouts/flash"), status: :too_many_requests }
       format.html { redirect_to return_path, alert: message }
     end
   end
   ```
3. Extend the cache comment in `production.rb`: the counters live in process memory, reset on every deploy or restart, and aren't shared between dynos. Move to Redis, Memcached, or Solid Cache before scaling out.
4. Spec setup: replacing `Rails.cache` doesn't work because `rate_limit` already captured the store object (`BetsController.cache_store` is the same NullStore instance as `Rails.cache`). Route its `increment` to a real store in a `before` block (rspec-mocks isn't available in `around` hooks):
   ```ruby
   let(:limiter_store) { ActiveSupport::Cache::MemoryStore.new }
   before { allow(Rails.cache).to receive(:increment) { |*args, **opts| limiter_store.increment(*args, **opts) } }
   ```
   The 20 allowed requests can all target one market: rejected bets count too.

## Acceptance criteria
- [ ] The 21st `POST /markets/:market_id/bets` from one user within a minute returns 429 with the flash message (turbo_stream) or redirects back with the alert (HTML), and `Betting::PlaceBet` isn't called for it.
- [ ] Another user is unaffected, and the same user can bet again after the window (`travel 61.seconds`).
- [ ] RSpec: a "rate limiting" context in `spec/requests/bets_spec.rb` covering both formats and both cases above.
- [ ] Cucumber: none; this isn't a user story.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. #18 (Daily credit top-up for players who run out) and #21 (PostHog product analytics for the betting funnel) also edit `BetsController`.
- **Out of scope:** limits on Studio actions, IP-based limits, a shared cache store.
- **Size:** S (≤ half a day)
