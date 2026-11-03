---
title: "Decide between Supabase and Heroku Postgres"
labels: ["type: spike", "area: devops", "area: database", "priority: P1 · iteration 2"]
milestone: "Iteration 2"
---
## Summary
The kickoff meeting planned Supabase, but production runs on Heroku Postgres. Decide which one we keep, and record why, before more features depend on the database: Action Cable's LISTEN/NOTIFY in #7/#8 and the per-PR databases in #1. Time-box: half a day.

## Context
- **Production today.** App `tolchu` runs on heroku-24 in the US Common Runtime (AWS us-east-1), with Heroku Postgres `essential-0`.
- **Database config.** [`config/database.yml`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/database.yml) reads `DATABASE_URL` in production, with `max_connections` = `RAILS_MAX_THREADS` (default 5).
- **Action Cable.** [`config/cable.yml`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/cable.yml) uses the `postgresql` adapter, which holds one long-lived LISTEN connection per web dyno.
- **Review apps.** [`app.json`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app.json) gives every review app its own `heroku-postgresql:essential-0`.
- **Budget.** If the team's ~$300 is the Heroku for GitHub Students offer, it is $13/month, and production already uses about $12 of it.

## Suggested implementation
1. **Fill in this comparison.** Verify every number on the vendor's pricing page.

| | Heroku essential-0 | Supabase Free | Supabase Pro |
|---|---|---|---|
| Cost | ≤ $5/month (~$0.007/h, prorated) | $0 | from $25/month |
| Storage | 1 GB | 500 MB | 8 GB |
| Connections | 20 | 60 direct / 200 pooled | 60 / 200 (Micro) |
| When idle | always on | paused after 7 days of inactivity | never paused |
| Backups | daily, 7 kept (`pg:backups:schedule`), no point-in-time recovery | none | daily, 7 days |
| Per-PR databases | included with review apps | none | branching at $0.01344 per branch-hour |

2. **Answer these questions.**
   - **Networking.** Supabase direct connections (`db.<ref>.supabase.co:5432`) are IPv6-only unless you buy the IPv4 add-on, and Heroku dynos need IPv4. That leaves the Supavisor pooler at `aws-0-<region>.pooler.supabase.com`, in one of two modes:
     - Session mode (port 5432) behaves like a normal connection.
     - Transaction mode (port 6543) needs `prepared_statements: false` (plus `advisory_locks: false` for migrations) and breaks LISTEN/NOTIFY, which Action Cable relies on.

     Is session mode enough for us?
   - **Latency.** Create a test project in us-east-1 and compare the server time of `GET /` (Heroku Metrics or `Server-Timing`) against the current database.
   - **SSL.** Does the connection URL carry `?sslmode=require`?
   - **Pausing.** The app may sit idle over Thanksgiving week, right before the final demo. Can we accept a paused project?
   - **Review apps.** The options:
     - keep Heroku essential-0 for review apps via `app.json`, even if production moves;
     - pay for Supabase branching;
     - share one database across all review apps (migrations from parallel PRs would collide).
   - **Supabase-only features.** Do we need anything only Supabase offers, such as its table editor or Storage for #9 (Let creators upload clips instead of pasting a URL)?
3. **Write the ADR.** Add `docs/decisions/0001-database.md` (new, the first ADR) with the sections Context, Options, Decision, Consequences. Include the filled-in table, the answers, and a recommendation. If the decision is to switch, add these migration steps:
   1. `heroku maintenance:on -a tolchu`, then `heroku pg:backups:capture -a tolchu` and `heroku pg:backups:download -a tolchu`.
   2. `pg_restore --no-owner --no-acl -d "$SUPABASE_SESSION_URL" latest.dump`, then compare row counts.
   3. Heroku won't let you `config:set` a `DATABASE_URL` that an add-on owns, so first run `heroku addons:attach <addon-name> --as OLD_DATABASE -a tolchu` and `heroku addons:detach DATABASE -a tolchu`. Then run `heroku config:set DATABASE_URL="postgres://…pooler.supabase.com:5432/postgres?sslmode=require" -a tolchu`.
   4. `heroku restart -a tolchu` and `heroku maintenance:off -a tolchu`. Then check `/up`, sign in, and place a bet.
   5. A week later, if nothing broke, run `heroku addons:destroy <addon-name> -a tolchu`.

## Acceptance criteria
- [ ] The ADR is merged with a clear decision and the evidence behind it, including latency numbers if a Supabase project was tried
- [ ] If switching, there is a follow-up issue for the migration with the steps above
- [ ] The team has agreed on the decision in the group chat
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing
- **Out of scope:** performing the migration, other providers (Neon, RDS)
- **Size:** S
