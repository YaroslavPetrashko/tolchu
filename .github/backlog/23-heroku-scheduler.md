---
title: "Schedule markets:lock_expired with Heroku Scheduler"
labels: ["type: chore", "area: devops", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
Run `bin/rails markets:lock_expired` every 10 minutes in production so the `status` and `locked_at` columns match what users see. The task exists, but nothing runs it on Heroku, so expired markets stay `open` in the database until someone settles them.

## Context
- [`Markets::LockExpired`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/lock_expired.rb) flips `open` markets past `locks_at` to `locked` (with `locked_at = locks_at`) in one `update_all`. [`lib/tasks/markets.rake`](https://github.com/YaroslavPetrashko/tolchu/blob/main/lib/tasks/markets.rake) wraps it and prints "Locked N expired markets."
- Betting is already safe without it: `Market#accepting_bets?` checks the clock. The job keeps the columns honest for anything that queries `Market.open` or `locked_at` (admin lists in #20, reporting).
- There is no scheduler: the [`Procfile`](https://github.com/YaroslavPetrashko/tolchu/blob/main/Procfile) has only `web` and `release`, and the app runs on one Basic dyno.

## Suggested implementation
1. Provision: `heroku addons:create scheduler:standard -a tolchu`. The add-on is free; each run is a one-off dyno billed per second.
2. Add the job in the dashboard (`heroku addons:open scheduler -a tolchu` → Add Job; jobs can't be created from the CLI): command `bin/rails markets:lock_expired`, every 10 minutes, dyno size Basic.
3. Verify: `heroku logs --dyno scheduler -a tolchu --tail` should print "Locked N expired markets." about every 10 minutes (`--ps scheduler` is the older spelling of the same filter). `heroku ps -a tolchu` shows a `scheduler.NNNN` dyno while a run is in progress.
4. Cost check: about 4,300 runs a month at roughly 10–15 seconds of boot time each is 12–18 Basic dyno-hours, well under $1 a month at the Basic rate.
5. Heroku documents that Scheduler is best-effort: a run can occasionally be skipped or happen twice. The task is idempotent (`update_all` only touches `open` rows past their deadline), so both are harmless; add a spec that proves it.
6. README, "Deployment (Heroku)" section: add a "Scheduled jobs" table (command, frequency, dyno size, why it exists) and the log command above.
7. When #10 (Sealed results: settle pre-recorded clips automatically at lock) adds its settle task, either schedule it the same way or call it from `markets:lock_expired`, so we keep one job and one boot per run.

## Acceptance criteria
- [ ] `heroku addons -a tolchu` lists `scheduler:standard`, and the job runs every 10 minutes on a Basic dyno.
- [ ] Scheduler logs show the task output; an open market past its deadline is `locked`, with `locked_at` equal to `locks_at`, within about 10 minutes.
- [ ] RSpec: [`spec/services/markets/lock_expired_spec.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/spec/services/markets/lock_expired_spec.rb) gains "a second run locks nothing" (the second call returns 0).
- [ ] Cucumber: none (no user-facing change).
- [ ] The README documents the job and how to read its logs.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Review apps from #1 (Enable Heroku Review Apps for per-PR deployments) don't need the job. #8 (Push locks and results to open feeds in real time) may later broadcast from this task.
- **Out of scope:** a custom clock process, Solid Queue recurring jobs, sub-minute locking (the clock check already handles that).
- **Size:** S (≤ half a day)
