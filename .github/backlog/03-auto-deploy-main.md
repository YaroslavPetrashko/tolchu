---
title: "Auto-deploy main to Heroku after CI passes"
labels: ["type: chore", "area: devops", "priority: P1 · iteration 2"]
milestone: "Iteration 2"
---
## Summary
Every merge to `main` should reach production automatically once CI is green. Then the live app always matches `main`, and nobody has to remember `git push heroku main`. CONTRIBUTING.md already says "`main` deploys to Heroku"; this issue makes that true.

## Context
- Deploys are manual today. [README → Deployment](https://github.com/YaroslavPetrashko/tolchu/blob/main/README.md#deployment-heroku) documents `heroku git:remote -a tolchu` followed by `git push heroku main`.
- [`Procfile`](https://github.com/YaroslavPetrashko/tolchu/blob/main/Procfile) runs `release: bin/rails db:migrate`. If a migration fails, Heroku aborts the release and the previous release keeps serving.
- [`.github/workflows/ci.yml`](https://github.com/YaroslavPetrashko/tolchu/blob/main/.github/workflows/ci.yml) runs on every `push` to `main`, so each squash-merge commit gets its own CI run to wait for.
- `GET /up` (`rails/health#show` in [`config/routes.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/routes.rb)) is the health check. [`production.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/environments/production.rb) exempts it from the SSL redirect.
- #1 creates the `tolchu` pipeline and connects it to GitHub.

## Suggested implementation
1. Heroku dashboard → app `tolchu` → Deploy → Automatic deploys: pick branch `main`, tick "Wait for CI to pass before deploy", and click "Enable Automatic Deploys". This needs the GitHub connection from #1, so Yaroslav (repo admin) does it.
2. Check that "Wait for CI" actually waits. Heroku describes it in terms of commit statuses, but our workflow reports GitHub Actions check runs. Merge a trivial PR, then confirm in the app's Activity tab that the build only starts after all four CI jobs finish.
3. If Heroku deploys before CI finishes, or never deploys, turn automatic deploys off and deploy from Actions instead. Add a job to `ci.yml` that runs after the other four, on `main` only:

```yaml
  deploy:
    needs: [ scan_ruby, scan_js, lint, test ]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with: { fetch-depth: 0 } # Heroku rejects pushes from shallow clones
      - run: git push https://heroku:${{ secrets.HEROKU_API_KEY }}@git.heroku.com/tolchu.git HEAD:refs/heads/main
```
   Create the token with `heroku authorizations:create -d "GitHub Actions deploy"` and store it as the repo secret `HEROKU_API_KEY`.
4. Rewrite the README "Deployment (Heroku)" section to cover:
   - Merging to `main` deploys automatically once CI passes.
   - Migrations run in the release phase.
   - `git push heroku main` remains the manual fallback, for example during a GitHub outage.
   - `heroku run bin/rails db:seed` is only needed on the very first deploy.
5. Optional smoke check. After the first automatic deploy, look at the repo's Environments sidebar. If Heroku posted a production deployment there, add a `deployment_status` workflow that curls `$environment_url/up` with `--retry 5` and fails on any non-200 response. If it didn't, skip this step: #24 (Error tracking with Sentry) will catch errors after deploys.

## Acceptance criteria
- [ ] Merging a PR to `main` starts a Heroku build only after the CI run on the merge commit is green (or the Actions `deploy` job, which `needs` all four CI jobs, pushes it)
- [ ] The release log of an automatic deploy shows `db:migrate` running
- [ ] `https://tolchu-24414638a003.herokuapp.com/up` returns 200 after the deploy
- [ ] The README "Deployment" section describes the automatic flow and the manual fallback
- [ ] `bin/ci` passes

## Notes
- **Depends on:** #1 (Enable Heroku Review Apps for per-PR deployments), which creates the pipeline and the GitHub connection
- **Out of scope:** a staging stage, preboot/zero-downtime deploys, Lighthouse runs after deploys (#4)
- **Size:** S
