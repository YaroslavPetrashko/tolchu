---
title: "Enable Heroku Review Apps for per-PR deployments"
labels: ["type: chore", "area: devops", "priority: P0 · now"]
milestone: "Iteration 1"
---
## Summary
As a reviewer I want every pull request deployed to its own temporary Heroku app, loaded with demo data, so I can try the change on a phone before approving instead of checking out the branch locally.

## Context
- [`app.json`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app.json) already defines `environments.review`: one Basic `web` dyno, its own `heroku-postgresql:essential-0`, and `postdeploy: bin/rails db:seed`. `SECRET_KEY_BASE` uses `"generator": "secret"`, so no secrets need to be copied.
- [`Procfile`](https://github.com/YaroslavPetrashko/tolchu/blob/main/Procfile) runs `release: bin/rails db:migrate`. On a new review app, Heroku runs the release phase before `postdeploy`, so the app migrates and then seeds.
- [`db/seeds.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/db/seeds.rb) creates the demo logins (`fan@tolchu.app` / `password123`, etc.) plus live, locked, and settled markets.
- The production app `tolchu` isn't in a pipeline yet, and Heroku isn't connected to GitHub. Deploys are `git push heroku main` ([README → Deployment](https://github.com/YaroslavPetrashko/tolchu/blob/main/README.md#deployment-heroku)).

## Suggested implementation
Yaroslav has to do steps 1–3. Connecting Heroku to GitHub needs repo admin rights, and the GitHub OAuth consent only works in a browser.
1. Create a pipeline with production as its only stage:
   `heroku pipelines:create tolchu --app tolchu --stage production`
2. Link GitHub to the Heroku account (Account settings → Applications → GitHub → Connect). Then connect the repo, either in the dashboard (Pipeline → Settings → Connect to GitHub) or with `heroku pipelines:connect tolchu --repo YaroslavPetrashko/tolchu`.
3. Enable review apps in the dashboard (Pipeline → Enable Review Apps), or with
   `heroku reviewapps:enable --pipeline tolchu --app tolchu --autodeploy --autodestroy --wait-for-ci`. Settings:
   - Create new review apps for new pull requests automatically: on
   - Wait for CI to pass: on
   - Destroy stale review apps automatically: after 1 day. The CLI flag doesn't set the number of days, so set it in the dashboard.
   - URL pattern: keep it random. Heroku warns that predictable names allow subdomain takeover.
4. Open a throwaway PR (a README typo is enough) and walk through the acceptance criteria below.
5. In [`CONTRIBUTING.md`](https://github.com/YaroslavPetrashko/tolchu/blob/main/CONTRIBUTING.md) "The loop", add three things: every PR gets a review app linked from the PR ("View deployment"); reviewers test there before approving; the app is destroyed when the PR closes.

Gotchas
- **Cost.** Heroku bills auto-created review apps to whoever connected GitHub. Each one costs about $0.017/h: a Basic dyno (~$0.01/h) plus essential-0 (~$0.007/h), roughly $0.40/day. If the team's ~$300 is the Heroku for GitHub Students offer, that's $13/month and unused credit expires each month. Production (Basic + essential-0) already uses about $12 of it, so keep the 1-day auto-destroy and close stale PRs.
- **Seeding.** `postdeploy` runs once, when the app is created; later pushes only migrate. If seeding failed, re-run `heroku run bin/rails db:seed -a <review-app>`. `db:seed` skips a database that already has `StuntLab`, so to start over use `demo:reset` from #6 (Add a demo reset task for presentations).
- **Wait for CI.** Heroku documents this setting in terms of commit statuses, but our CI reports GitHub Actions check runs. In step 4, confirm the app is only created after the `CI` workflow finishes.

## Acceptance criteria
- [ ] Pipeline `tolchu` exists, `tolchu` is its production stage, and the pipeline is connected to `YaroslavPetrashko/tolchu`
- [ ] A test PR gets a review app only after CI passes, and the PR shows a deployment link
- [ ] The review app serves the feed with seeded demo markets, `fan@tolchu.app` / `password123` can sign in, and `GET /up` returns 200
- [ ] Closing the test PR destroys the review app and its database
- [ ] Stale review apps auto-destroy after 1 day
- [ ] CONTRIBUTING.md documents review apps
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Needs Yaroslav for the GitHub connection.
- **Out of scope:** auto-deploying `main` (#3 Auto-deploy main to Heroku after CI passes), Lighthouse runs against review apps (#4)
- **Size:** S
