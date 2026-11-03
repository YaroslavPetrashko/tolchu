---
title: "Concurrency specs for simultaneous bets and settlements"
labels: ["type: test", "area: betting-engine", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
The betting engine relies on row locks that no spec exercises with truly parallel transactions. Before real users hit the final demo, prove that double taps, parallel bets, and racing settlements can't create, lose, or double-pay credits.

## Context
- [`Betting::PlaceBet`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/betting/place_bet.rb) locks the market row (`@market.lock!`) before validating; the unique index on `bets (user_id, market_id)` is the fallback.
- [`Wallet#post!`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/wallet.rb) locks the user row (`user.lock!`) per credit movement, backed by the `users_balance_non_negative` constraint.
- [`Markets::Resolve`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/resolve.rb) and [`Markets::Cancel`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/cancel.rb) lock the market, then all affected users in id order; [`Markets::Lock`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/lock.rb) locks the market.
- [`spec/rails_helper.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/spec/rails_helper.rb) sets `use_transactional_fixtures = true`. In Rails 8.1 that pins one connection shared by all threads (`pin_connection!` in `ActiveRecord::TestFixtures`), so threads in a normal spec never wait on each other's locks. The only race test stubs `Bet#save` to raise.

## Suggested implementation
1. `spec/support/concurrency.rb` (new), included with `config.include_context "real concurrency", :concurrency`. `database_cleaner-active_record` is already in the Gemfile:
```ruby
RSpec.shared_context "real concurrency" do
  self.use_transactional_tests = false
  after { DatabaseCleaner.clean_with(:truncation) }

  def in_parallel(count)
    ready, go = Concurrent::CountDownLatch.new(count), Concurrent::CountDownLatch.new(1)
    threads = Array.new(count) do |i|
      Thread.new { ActiveRecord::Base.connection_pool.with_connection { ready.count_down; go.wait; yield i } }
    end
    ready.wait
    go.count_down
    threads.map(&:value) # re-raises anything a thread raised
  end
end
```
2. Connections: [`config/database.yml`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/database.yml) uses `max_connections` (default 5, and the example's own thread holds one). Set `max_connections: 10` under `test:` and use at most 8 threads.
3. Rules: each thread loads its own records (`Market.find(id)`, `User.find(id)`) and never shares Active Record objects; no `freeze_time`/`travel_to` (time stubs are global); factory users have no starting ledger entry, so compare `balance == starting_balance + ledger_entries.sum(:amount)` or create users with `User.register`.
4. `spec/services/concurrency_spec.rb` (new), tagged `:concurrency`:
   - one user submits the same market from 5 threads: one success, four "You already made a prediction on this market", one `stake` entry, `total_pool` and `bets_count` match;
   - one user with 100 credits stakes 30 on 5 markets at once: exactly 3 succeed, balance ends at 10, never negative;
   - 4 bettors race `Markets::Lock`: each result is a success or "Betting is closed for this market", pools equal `bets.sum(:stake)`, and every bet's `created_at <= market.locked_at`;
   - on a locked market, `Markets::Resolve` twice, and `Resolve` vs `Cancel`: one succeeds, the other gets "This market has already been settled"; no bet gets more than one payout or refund entry; payouts + `creator_reward` + `house_take` == `total_pool`;
   - two markets sharing bettors resolved in parallel: both succeed, no `ActiveRecord::Deadlocked`.
5. The Lock race case is the regression test for a fix already on `main` (commit `67f6435`): `Markets::Lock`, `Resolve`, and `Cancel` used to read the clock in `initialize`, before `@market.lock!` waited for in-flight bets, so `locked_at` could predate a bet that committed first. They now read it after taking the lock. If this case ever fails, that fix regressed.

## Acceptance criteria
- [ ] RSpec: the five cases in `spec/services/concurrency_spec.rb` pass 20 runs in a row locally (`bundle exec rspec --tag concurrency`)
- [ ] Concurrency examples leave no rows behind; the full suite still passes in any order
- [ ] The Lock race case asserts every bet's `created_at <= market.locked_at` (guards the clock-after-lock fix)
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing
- **Related:** #31 (Add credits to an existing prediction before lock) should add a top-up case here; #30 (Architecture notes: parimutuel math, ledger invariants, market lifecycle) should link these specs.
- **Out of scope:** HTTP load testing.
- **Size:** M
