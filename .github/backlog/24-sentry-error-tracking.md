---
title: "Error tracking with Sentry"
labels: ["type: chore", "area: devops", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
Report production exceptions with a stack trace and the affected user id, so we hear about bugs before testers do. Today an error shows `public/500.html` to the user and leaves a line in Heroku logs that nobody watches.

## Context
- Production logs only to STDOUT ([`production.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/environments/production.rb)) with `consider_all_requests_local = false`; nothing alerts us.
- `Current.user` is set by `before_action :resume_session` in [`ApplicationController`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/application_controller.rb) on every request.
- Secrets come from Heroku config vars, not encrypted credentials ([`app.json`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app.json) generates `SECRET_KEY_BASE`).
- The current SDK major is sentry-ruby 7 (September 2026). It deprecated `send_default_pii` in favor of a granular `data_collection` setting and plans looser defaults in 8.0.

## Suggested implementation
1. Gemfile (default group): `gem "sentry-ruby"` and `gem "sentry-rails"`.
2. `config/initializers/sentry.rb`:
   ```ruby
   Sentry.init do |config|
     config.dsn = ENV["SENTRY_DSN"]
     config.enabled_environments = %w[production]
     config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
     config.traces_sample_rate = 0.05 # traces count against the free quota
     # Replaces the deprecated send_default_pii = false. Set explicitly because 8.0 flips the default.
     config.data_collection.user_info = false
   end
   ```
3. User context, id only: in `ApplicationController`, after `before_action :resume_session`, add `before_action { Sentry.set_user(id: Current.user.id) if Current.user }`. If the test event arrives without `user.id`, `user_info = false` is also dropping explicitly set users; in that case allow it and strip everything but `id` in `before_send`.
4. `heroku config:set SENTRY_DSN=… -a tolchu`. Don't put it in `app.json`, so review apps stay silent.
5. After installing, review the 7.x defaults: logs and metrics are on by default since 7.0. Turn off sentry-rails structured logging (`config.rails.structured_logging.enabled = false`) if it eats the free quota; Heroku already keeps our logs.
6. Optional: `heroku labs:enable runtime-dyno-metadata -a tolchu` so events carry the release (slug commit). A browser SDK can come later.
7. Seats: Sentry's free Developer plan has a single user. Claim the Sentry offer in the GitHub Student Developer Pack for team seats, or point alerts at a shared inbox.
8. Alternative if Sentry is a hassle: Honeybadger has a free tier and a simple Rails gem (`honeybadger`, `HONEYBADGER_API_KEY`); the same rules apply (production only, id only).

## Acceptance criteria
- [ ] `heroku run -a tolchu "bin/rails runner 'Sentry.capture_message(%(Sentry test)); Sentry.close'"` shows up in Sentry tagged `production`.
- [ ] A real exception in production appears with a stack trace and `user.id`, and no email, username, or IP address.
- [ ] Nothing is sent from development, test, CI, or review apps.
- [ ] The README's "Deployment (Heroku)" section documents `SENTRY_DSN`.
- [ ] RSpec: the suite passes with the gems loaded (Sentry is inert without a DSN); add a request spec that `Sentry.set_user` receives `id:` for a signed-in request.
- [ ] Cucumber: none (no user-facing change).
- [ ] `bin/ci` passes, including `bin/bundler-audit`

## Notes
- **Depends on:** nothing. Pairs with #21 (PostHog product analytics for the betting funnel), which uses the same "user id only" rule, and #3 (Auto-deploy main to Heroku after CI passes) for release tracking.
- **Out of scope:** performance dashboards, uptime monitoring, JavaScript error tracking and source maps.
- **Size:** S (≤ half a day)
