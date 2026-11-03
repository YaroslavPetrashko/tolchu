---
title: "Add a demo reset task for presentations"
labels: ["type: chore", "area: devops", "area: database", "priority: P1 · iteration 2"]
milestone: "Iteration 2"
---
## Summary
As a presenter I want one command that puts production back into its freshly seeded state, so every demo and user-testing session starts from a known, believable feed. That state is: live markets with weeks left, one market waiting for a result, two settled ones, and untouched demo balances.

## Context
- [`db/seeds.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/db/seeds.rb) builds the demo data through the real services (`User.register`, `Betting::PlaceBet`, `Markets::Lock`/`Resolve`). The four open markets lock 21–30 days after seeding (`closes_in: 21.days` … `30.days`). If production was seeded on Nov 3, the first one locks on Nov 24, two days before Thanksgiving. Every demo also changes balances and may settle the locked basketball market (`Does #67 finish at the rim?`).
- Seeds are guarded by `return if User.exists?(username: "StuntLab")`, so `db:seed` on a used database does nothing.
- Rails ships `db:seed:replant`, which runs `db:truncate_all` and then `db:seed`. On Postgres it issues a single `TRUNCATE TABLE …` over every table except `schema_migrations` and `ar_internal_metadata`, without `RESTART IDENTITY`. In production it raises `ActiveRecord::ProtectedEnvironmentError` unless `DISABLE_DATABASE_ENVIRONMENT_CHECK=1` is set.
- Rake tasks live in [`lib/tasks/markets.rake`](https://github.com/YaroslavPetrashko/tolchu/blob/main/lib/tasks/markets.rake). Their spec pattern is in [`spec/services/markets/lock_expired_spec.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/spec/services/markets/lock_expired_spec.rb): `Rails.application.load_tasks`, then `Rake::Task[...].execute`.

## Suggested implementation
1. Add `lib/tasks/demo.rake` (new):

```ruby
namespace :demo do
  desc "Delete ALL data and reload db/seeds.rb (requires CONFIRM=tolchu)"
  task reset: :environment do
    unless ENV["CONFIRM"] == "tolchu"
      abort "demo:reset deletes every user, bet and market. Re-run with CONFIRM=tolchu."
    end

    ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"] = "1" # CONFIRM is the explicit opt-in
    Rake::Task["db:seed:replant"].invoke
    puts "Demo reset: #{User.count} users, #{Market.count} markets."
  end
end
```
2. Document it in the README "Deployment" section:
   - Production: `heroku run -a tolchu -e CONFIRM=tolchu -- bin/rails demo:reset`
   - Locally: `CONFIRM=tolchu bin/rails demo:reset`
3. Add `spec/tasks/demo_rake_spec.rb` (new):
   - Without `CONFIRM`, `expect { Rake::Task["demo:reset"].execute }.to raise_error(SystemExit, /CONFIRM=tolchu/)`, and a user created beforehand still exists.
   - With `CONFIRM=tolchu`, stub `Rake::Task["db:seed:replant"]` and expect it to receive `invoke`. Don't run the real replant inside RSpec: `db:truncate_all` opens its own connection and would block on the open test transaction's locks.
   - Remove `CONFIRM` and `DISABLE_DATABASE_ENVIRONMENT_CHECK` from `ENV` in an `after` block.
4. Add `spec/db/seeds_spec.rb` (new) for the seeds guard. On an empty database (the transactional test DB), `Rails.application.load_seed` creates 10 users and 7 markets: 4 open, 1 locked, 2 resolved. A second `load_seed` changes nothing and prints "Demo data already loaded. Skipping." That proves seeding still works right after a truncate. The second load re-assigns `DEMO_PASSWORD` and Ruby will warn; guard it with `unless defined?(DEMO_PASSWORD)`.

Gotchas
- Everyone is signed out, because `sessions` is truncated too. Ids keep counting up, so an old session cookie can't match a new session row.
- Run it a few minutes before a presentation, not during one. TRUNCATE takes an exclusive lock and waits for in-flight requests to finish.
- `lib/tasks/*.rake` counts toward coverage (`.simplecov` only skips `cucumber.rake`), which is one more reason to add the spec.

## Acceptance criteria
- [ ] `bin/rails demo:reset` without `CONFIRM=tolchu` aborts with a clear message and deletes nothing
- [ ] With `CONFIRM=tolchu` it empties every table and reseeds; open markets then lock 21–30 days after the reset
- [ ] It runs in production through `heroku run` without a `ProtectedEnvironmentError`
- [ ] RSpec: `spec/tasks/demo_rake_spec.rb` covers the guard and the replant invocation; `spec/db/seeds_spec.rb` covers the counts and that a second load is a no-op
- [ ] The README documents both commands
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing
- **Out of scope:** scheduled automatic resets, resetting review apps (they're seeded fresh when created, see #1)
- **Size:** S
