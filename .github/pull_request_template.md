## What and why

Closes #<!-- issue number: one PR per issue -->

<!-- One or two sentences on what changed and why. -->

## How to test

<!-- Steps a reviewer can follow locally or on the review app. -->

1.

## Screenshots

<!-- Required for UI changes (phone width and desktop). Delete if not applicable. -->

## Checklist

- [ ] Scoped to the linked issue (no drive-by changes)
- [ ] RSpec specs added or updated for new logic
- [ ] Cucumber scenario added or updated for user-facing behaviour
- [ ] `bin/ci` passes locally (RuboCop, Brakeman, bundler-audit, RSpec, Cucumber)
- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org) (`feat:`, `fix:`, `chore:` …)
- [ ] Migrations are reversible and `db/schema.rb` is committed (if the schema changed)
