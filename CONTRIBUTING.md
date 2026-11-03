# How we work

## The loop

1. **Pick an issue** from the board, starting with the highest priority (`P0` first). Assign yourself so nobody
   else starts it.
2. **Branch from `main`**, one branch per issue:
   `<type>/<issue-number>-<short-description>`, e.g. `feat/12-live-pool-updates`, `fix/31-old-safari-406`,
   `chore/4-lighthouse-ci`.
3. **Commit in small, clean steps** using [Conventional Commits](https://www.conventionalcommits.org):
   `feat(feed): stream pool updates over Turbo`, `fix(wallet): …`, `test(betting): …`, `chore(ci): …`.
   One logical change per commit. No "wip" or "fix stuff".
4. **Open a PR** that says `Closes #<issue>` and fills in the template. Keep it scoped to that one issue.
   Smaller PRs get reviewed faster.
5. **CI must be green** (RuboCop, Brakeman, bundler-audit, RSpec, Cucumber), and **one teammate must approve**.
6. **Squash-merge** and delete the branch. `main` deploys to Heroku.

Because every PR maps to one self-contained issue, we can all work in parallel without stepping on each other.
If two issues touch the same file, coordinate in the group chat before starting.

## Labels

Every issue carries one label from each group (source of truth: [`.github/labels.yml`](.github/labels.yml),
synced with `bin/github-labels`).

| Group | Labels | Meaning |
|---|---|---|
| **type** | `feature` `bug` `chore` `test` `docs` `refactor` `spike` | What kind of work it is |
| **area** | `frontend` `backend` `betting-engine` `creator-tools` `auth` `video` `devops` `database` `analytics` | What part of the product it touches (can have several) |
| **priority** | `P0 · now` `P1 · iteration 2` `P2 · final demo` `P3 · backlog` | How urgent it is, tied to course deadlines |

Milestones mirror the deadlines: **Iteration 1** (Nov 9), **Iteration 2**, **Final demo**.

## Before you push

```sh
bin/ci   # runs everything CI runs, locally
```

- New logic gets RSpec specs: models and services in `spec/models` and `spec/services`, HTTP behaviour in `spec/requests`.
- New user-facing behaviour gets a Cucumber scenario in `features/`. Write the story in the user's words; put the
  plumbing in step definitions.
- Money moves only through `Wallet` (never `update(balance: …)`), and market state changes only through the
  services in `app/services/markets/`. The tests check that ledgers balance.

## Running the app

See the [README](README.md#running-locally). Demo logins are listed there too.
