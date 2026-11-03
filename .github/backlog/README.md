# Initial issue backlog

38 issue drafts for everything beyond the Iteration 1 MVP, written against the code as of Nov 3. Each one is
scoped to a single PR and labelled by type, area, and deadline-based priority (see `.github/labels.yml`).

| Priority | Issues | Milestone |
|---|---|---|
| `P0 · now` | 2 (review apps, branch protection) | Iteration 1 (due Nov 9) |
| `P1 · iteration 2` | 11 | Iteration 2 |
| `P2 · final demo` | 16 | Final demo |
| `P3 · backlog` | 9 | none |

## Publishing (once, repo admin)

```sh
gh auth login
bin/github-backlog
```

The script creates the labels, the three milestones, and one issue per file, then rewrites the drafts' `#N`
cross-references to the real issue numbers. It is safe to re-run.

After publishing, GitHub Issues are the source of truth. Delete this folder in a `chore:` PR.
