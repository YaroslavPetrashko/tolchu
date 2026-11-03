---
title: "Run Lighthouse CI against production and review apps"
labels: ["type: chore", "area: devops", "area: frontend", "priority: P1 · iteration 2"]
milestone: "Iteration 2"
---
## Summary
We want Lighthouse scores (performance, accessibility, best practices, SEO) for every review app and a weekly run against production. Then a regression shows up next to the PR that caused it, and we see where we stand before real-user testing after Thanksgiving.

## Context
- Three guest pages are worth auditing:
  - the feed `/` ([`markets/index`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/index.html.erb))
  - `/how-it-works` ([`pages/how_it_works`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/pages/how_it_works.html.erb))
  - sign-in at `/session/new` ([`sessions/new`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/sessions/new.html.erb))

  Routes are in [`config/routes.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/routes.rb).
- The feed is video-heavy:
  - Every card in [`markets/_market.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_market.html.erb) renders `<video preload="metadata">` pointing at a hotlinked 720p Mixkit MP4, with no poster image.
  - [`clip_controller.js`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/javascript/controllers/clip_controller.js) autoplays the card that is 60% visible.
  - The LCP element is probably the first card's video.
- For review apps (#1), Heroku publishes a GitHub deployment status carrying the app URL. Production deploys come from #3.

## Suggested implementation
1. Add `.github/workflows/lighthouse.yml` (new) with three triggers and one job:

```yaml
on:
  deployment_status:
  workflow_dispatch:
    inputs:
      url: { description: "Base URL to audit", default: "https://tolchu-24414638a003.herokuapp.com" }
  schedule:
    - cron: "0 13 * * 1" # Mondays, 8–9am Eastern
jobs:
  audit:
    if: github.event_name != 'deployment_status' || (github.event.deployment_status.state == 'success' && github.event.deployment_status.environment_url != '')
    runs-on: ubuntu-latest
    env:
      BASE_URL: ${{ github.event.deployment_status.environment_url || inputs.url || 'https://tolchu-24414638a003.herokuapp.com' }}
```
2. Add the job's steps:
   - `actions/checkout@v6`
   - Strip any trailing slash: `echo "BASE_URL=${BASE_URL%/}" >> "$GITHUB_ENV"`
   - `treosh/lighthouse-ci-action@v12` with these inputs:
     - `urls:` `${{ env.BASE_URL }}/`, `${{ env.BASE_URL }}/how-it-works`, `${{ env.BASE_URL }}/session/new`
     - `configPath: ./lighthouserc.json`
     - `runs: 3`
     - `uploadArtifacts: true`
     - `temporaryPublicStorage: true` (report links stay public for 7 days and are printed in the log and the `links` output)
3. Add `lighthouserc.json` (new) at the repo root. Accessibility fails the job; the other categories only warn:

```json
{ "ci": { "assert": { "assertions": {
  "categories:accessibility": ["error", { "minScore": 0.9 }],
  "categories:performance": ["warn", { "minScore": 0.8 }],
  "categories:best-practices": ["warn", { "minScore": 0.9 }],
  "categories:seo": ["warn", { "minScore": 0.9 }]
} } } }
```
4. Run it once by hand (Actions → Lighthouse → Run workflow) to get a baseline. If accessibility already scores below 0.9, start it at `warn` and link the failures to #25 (Accessibility audit of the feed, bet form, and studio) rather than merging an always-red workflow.
5. Record the baseline scores in the PR description, but don't fix them in this PR. Likely follow-ups for the feed: posters, plus `preload="none"` on every card after the first, with `clip_controller` switching a card to `preload="auto"` as it nears the viewport.

Gotchas
- For `deployment_status`, Actions runs the workflow file from the deployed commit. PRs opened before this merges won't trigger it until they're updated from `main`.
- Heroku documents deployment statuses for review apps. If production auto-deploys (#3) don't create one, production is still covered by the weekly schedule and manual runs.
- Only guest pages are audited. Signed-in pages would need a login script.

## Acceptance criteria
- [ ] A successful review-app deployment triggers an audit of that app's URL
- [ ] Manual dispatch audits production by default, or any URL passed as `url`
- [ ] The weekly schedule audits production
- [ ] The job log links public reports for all three pages, and results are uploaded as an artifact
- [ ] An accessibility score below 0.9 fails the job; the other categories only warn
- [ ] Baseline scores are recorded in the PR description
- [ ] `bin/ci` passes

## Notes
- **Depends on:** #1 (Enable Heroku Review Apps for per-PR deployments) and #3 (Auto-deploy main to Heroku after CI passes) for deployment-triggered runs; manual and scheduled runs work without them
- **Out of scope:** fixing the scores, making Lighthouse a required check (#2), auditing signed-in pages
- **Size:** S
