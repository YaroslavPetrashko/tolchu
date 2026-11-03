---
title: "Fail CI when merged coverage drops below 90%"
labels: ["type: chore", "area: devops", "priority: P1 · iteration 2"]
milestone: "Iteration 2"
---
## Summary
CI should fail when combined RSpec + Cucumber line coverage drops below 90%. That way new code arrives with tests, and the coverage figure we report doesn't quietly erode before the final demo.

## Context
- **Shared config.** Both suites use [`.simplecov`](https://github.com/YaroslavPetrashko/tolchu/blob/main/.simplecov): branch coverage on, `merge_timeout 3600`, and a `Services` group.
- **One slice per suite.** [`spec/rails_helper.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/spec/rails_helper.rb) and [`features/support/env.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/features/support/env.rb) each set a `SimpleCov.command_name` (`"RSpec"` / `"Cucumber"`) and then call `SimpleCov.start "rails"`.
- **What SimpleCov 1.3.2 writes** (version from `Gemfile.lock`) after each suite:
  - `coverage/.resultset.json`: one entry per suite.
  - `coverage/.last_run.json`: `{"result": {"line": 99.42, "branch": 91.8}}`, floored to 2 decimals. It's only written after a successful run.
  - `coverage/coverage.json`: `meta.command_names` (`["Cucumber", "RSpec"]`), `total.lines.percent`, `total.branches.percent`, and per-group totals.
- **Current numbers.** Merged coverage is about 97.5–99.4% of lines (README vs. the latest local run) and 91.8% of branches.
- **Where it runs.** The [`test` job](https://github.com/YaroslavPetrashko/tolchu/blob/main/.github/workflows/ci.yml) runs RSpec, then Cucumber, then uploads `coverage/` with `if: always()`. [`config/ci.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/ci.rb) is the local `bin/ci` equivalent.

## Suggested implementation
1. Don't set a minimum in `.simplecov`. SimpleCov checks thresholds when each test process exits, against that process's merged result. RSpec runs first in CI, so it would be judged on RSpec coverage alone. Locally, even `bundle exec rspec spec/models/user_spec.rb` would fail on coverage.
2. Add `bin/coverage-check` (new, executable). It reads the merged `coverage/coverage.json`, refuses a report that doesn't contain both suites, writes a job summary, and exits non-zero below the minimum:

```ruby
#!/usr/bin/env ruby
require "json"

report = JSON.parse(File.read(File.expand_path("../coverage/coverage.json", __dir__)))
suites = report.dig("meta", "command_names").to_a
abort "coverage.json only has #{suites.inspect}; run RSpec and Cucumber first" unless (%w[RSpec Cucumber] - suites).empty?

lines, branches = report["total"].values_at("lines", "branches").map { |total| total["percent"].floor(2) }
minimum = Float(ENV.fetch("MIN_LINE_COVERAGE", "90"))
summary = "### Merged coverage\n| Lines | Branches |\n|---|---|\n| #{lines}% | #{branches}% |\n"
File.write(ENV["GITHUB_STEP_SUMMARY"], summary, mode: "a") if ENV["GITHUB_STEP_SUMMARY"]
abort "Line coverage #{lines}% is below #{minimum}%" if lines < minimum
puts "Line coverage #{lines}% (minimum #{minimum}%), branch coverage #{branches}%"
```
3. In `ci.yml`, add a step to the `test` job between "Run Cucumber user stories" and "Upload coverage report": `name: Enforce 90% merged line coverage`, `run: bin/coverage-check`. The upload step keeps `if: always()`, so the HTML report can still be downloaded when the gate fails.
4. In `config/ci.rb`, add `step "Tests: Coverage (90% lines)", "bin/coverage-check"` right after the Cucumber step.
5. Optional: add per-group rows from `report["groups"]` (Services, Models, Controllers, …) to the summary table.
6. In the README "Testing" section, mention the gate and the `MIN_LINE_COVERAGE` override.

Gotchas
- Don't gate branch coverage at 90% yet. It's 91.8% today, so a single untested `if` would turn CI red. Report it only, or set an 85% floor if the team wants one.
- Locally, `merge_timeout 3600` can merge in a run of the other suite from up to an hour ago. Run both suites, or `bin/ci`, before trusting the number.

## Acceptance criteria
- [ ] CI's `test` job runs `bin/coverage-check` after Cucumber and fails below 90% merged line coverage
- [ ] `MIN_LINE_COVERAGE=100 bin/coverage-check` exits non-zero locally; the default passes
- [ ] The workflow run's summary shows merged line and branch percentages
- [ ] Running a single spec file locally doesn't fail because of coverage
- [ ] `bin/coverage-check` refuses a report that contains only one suite
- [ ] `bin/ci` runs the same check and passes

## Notes
- **Depends on:** nothing
- **Out of scope:** per-file minimums or a ratchet (`simplecov ratchet`), patch coverage (`simplecov patch --minimum`), coverage badges
- **Size:** S
