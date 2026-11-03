---
title: "Daily credit top-up for players who run out"
labels: ["type: feature", "area: betting-engine", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
As a player who has lost most of my credits, I want to claim a small top-up once a day so I can keep playing instead of leaving. With 1,000 starting credits and stakes up to 100, a few bad calls during real-user testing can leave a tester unable to bet.

## Context
- Credits move only through [`Wallet`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/wallet.rb): `credit!` locks the user row, updates `balance`, and appends a `LedgerEntry`. Kinds are an enum in [`LedgerEntry`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/ledger_entry.rb) (no DB check constraint on `kind`), and `LedgerEntry#description` labels them on the wallet page.
- [`Betting::PlaceBet#debit_stake`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/betting/place_bet.rb) fails with "You don't have enough credits for that stake (balance: N)". [`BetsController#create`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/bets_controller.rb) shows errors through [`layouts/_flash.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/layouts/_flash.html.erb), which already skips non-string flash values.

## Suggested implementation
1. Migration: `add_column :users, :last_top_up_at, :datetime`.
2. `LedgerEntry`: add `daily_top_up: "daily_top_up"` to the enum and `when :daily_top_up then "Daily top-up"` to `#description`.
3. New service `app/services/credits/claim_daily_top_up.rb` with `THRESHOLD = 50`, `AMOUNT = 200`, `COOLDOWN = 24.hours`, a class method `eligible?(user, now: Time.current)` (`balance < THRESHOLD` and `last_top_up_at` is nil or at least 24 hours ago), and:
   ```ruby
   def perform
     User.transaction do
       @user.lock! # re-read balance and last_top_up_at under the row lock
       fail!("Top-ups are for balances under #{THRESHOLD} credits, once every 24 hours") unless self.class.eligible?(@user, now: @now)

       @user.update_columns(last_top_up_at: @now)
       @user.wallet.credit!(AMOUNT, kind: :daily_top_up)
     end
   end
   ```
   The row lock makes double claims safe: a second concurrent request waits on `lock!`, then sees the new `last_top_up_at` and fails.
4. Nest `resource :top_up, only: :create` inside `resource :wallet` (`POST /wallet/top_up`, `wallet_top_up_path`) with a new `TopUpsController#create` that calls the service and does `redirect_back_or_to wallet_path` with `notice: "200 credits added. Good luck!"` or the error as `alert:`.
5. Wallet page ([`wallets/show.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/wallets/show.html.erb)): in `.wallet-hero`, show `button_to "Claim 200 free credits", wallet_top_up_path` when eligible, or "Next top-up in 5 hours" when the balance is low but the cooldown is running.
6. Rejected bets: in the failure branch of `BetsController#create`, set `flash.now[:offer_top_up] = true` when `Credits::ClaimDailyTopUp.eligible?(Current.user.reload)`, and pass it on the HTML redirect (`flash: { offer_top_up: true }`). In `_flash.html.erb`, render the claim button under the alert when `flash[:offer_top_up]` is set; the existing `next unless message.is_a?(String)` keeps the boolean from rendering as a message.

## Acceptance criteria
- [ ] A user with a balance under 50 and no top-up in the last 24 hours can claim +200 credits; the ledger shows "Daily top-up" with the right `balance_after`.
- [ ] A balance of 50 or more, or a claim less than 24 hours ago, is refused and changes nothing.
- [ ] A rejected bet from an eligible user offers the claim button, on the feed and on the market page.
- [ ] Two simultaneous claims produce exactly one credit.
- [ ] RSpec: `spec/services/credits/claim_daily_top_up_spec.rb` (balance of exactly 49 and 50, cooldown of exactly 24 hours using `travel`, sequential double claim, and a two-thread race in a group with `self.use_transactional_tests = false` plus manual cleanup, since transactional tests share one connection across threads); `spec/models/ledger_entry_spec.rb` (description); `spec/requests/top_ups_spec.rb`; `spec/requests/bets_spec.rb` (offer present in the turbo_stream and HTML responses).
- [ ] Cucumber `features/wallet/daily_top_up.feature`: with a balance of 30, predicting 50 credits fails, I press "Claim 200 free credits", my balance is 230, and my wallet shows "Daily top-up" for +200.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Reuse the thread harness from #28 (Concurrency specs for simultaneous bets and settlements) if it lands first. #30 (Architecture notes: parimutuel math, ledger invariants, market lifecycle) should list the new ledger kind. #22 also edits `BetsController`.
- **Out of scope:** streaks or larger bonuses, buying credits, counting pending stakes toward eligibility, admin credit grants.
- **Size:** M (1–2 days)
