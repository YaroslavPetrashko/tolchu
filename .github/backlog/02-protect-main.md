---
title: "Protect main: require one approving review and passing CI"
labels: ["type: chore", "area: devops", "priority: P0 · now"]
milestone: "Iteration 1"
---
## Summary
GitHub should enforce the workflow that CONTRIBUTING.md describes: a PR, one teammate's approval, and green CI. Then nobody can push straight to `main` or merge a red build, and history stays one squashed commit per issue.

## Context
- [`CONTRIBUTING.md`](https://github.com/YaroslavPetrashko/tolchu/blob/main/CONTRIBUTING.md) already describes the loop (one branch and PR per issue, green CI, one approval, squash-merge, delete the branch). Nothing enforces it yet.
- [`.github/workflows/ci.yml`](https://github.com/YaroslavPetrashko/tolchu/blob/main/.github/workflows/ci.yml) runs on every PR and on pushes to `main`. Its four jobs are `scan_ruby`, `scan_js`, `lint`, and `test`. None has a `name:`, so the check names are exactly those ids.
- `YaroslavPetrashko/tolchu` is a personal repo. Only the owner can change settings; collaborators get write access.

## Suggested implementation
Yaroslav has to do every step, because only the repo owner can change settings.
1. **Collaborators first.** Everyone posts their GitHub username in the group chat. Add them under Settings → Collaborators, and each person accepts the invite. Approvals only count from people with write access.
2. **Settings → General → Pull Requests:**
   - Allow squash merging only.
   - Set the default squash commit message to "Pull request title", so Conventional Commit PR titles become the commit titles.
   - Turn on "Automatically delete head branches" and "Allow auto-merge".

   CLI equivalent (the default-message option has no flag in this command; set it in the UI):
   `gh repo edit YaroslavPetrashko/tolchu --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false --delete-branch-on-merge --enable-auto-merge`
3. **Settings → Branches → classic protection rule for `main`** (a Ruleset under Settings → Rules works the same way). Require a PR with 1 approval, dismiss stale approvals on new commits, require the four status checks, require branches to be up to date, require linear history, include administrators, and block force pushes and deletions. CLI equivalent:

```sh
gh api -X PUT repos/YaroslavPetrashko/tolchu/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": { "strict": true,
    "checks": [{ "context": "scan_ruby" }, { "context": "scan_js" }, { "context": "lint" }, { "context": "test" }] },
  "required_pull_request_reviews": { "required_approving_review_count": 1, "dismiss_stale_reviews": true },
  "enforce_admins": true,
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```
4. In CONTRIBUTING.md step 5, add: "`main` is protected: GitHub blocks the merge until CI is green and a teammate approves."

Gotchas
- **No self-approval.** GitHub doesn't let you approve your own PR, so every PR needs one of the other three.
- **Visibility matters.** The repo is public (checked Nov 3), so branch protection works on the free plan. If it is ever made private, protection on a personal repo needs GitHub Pro (free with the GitHub Student Developer Pack).
- **Up to date is strict.** Each time something merges, other open PRs need "Update branch" and a fresh CI run. Dependabot ([`.github/dependabot.yml`](https://github.com/YaroslavPetrashko/tolchu/blob/main/.github/dependabot.yml): weekly, up to 10 PRs per ecosystem) rebases its own PRs but still needs an approval.
- **Check names.** If a job in `ci.yml` is renamed or a new required job is added, update the required checks. Otherwise PRs wait forever on "Expected — Waiting for status to be reported".

## Acceptance criteria
- [ ] All four teammates are collaborators
- [ ] `git push origin main` is rejected
- [ ] A PR with failing CI or no approval can't be merged; with an approval and green checks, the only option is "Squash and merge"
- [ ] Pushing a commit after approval dismisses the approval
- [ ] Merged branches are deleted automatically
- [ ] CONTRIBUTING.md mentions the protection
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing
- **Out of scope:** CODEOWNERS, signed commits, required deployments
- **Size:** S
