---
title: "Notify bettors when their prediction settles"
labels: ["type: feature", "area: frontend", "area: backend", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
As a bettor, I want a notification when a market I predicted on is resolved or cancelled, so I find out whether I won without scrolling back through the feed. Betting windows run up to 3 days, so results often land long after the bet.

## Context
- Settlement happens only in [`Markets::Resolve`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/resolve.rb) (`settle` sets each bet's `payout` and `status` to won/lost/refunded and credits wallets) and [`Markets::Cancel`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/cancel.rb) (refunds every bet), each inside one `Market.transaction`.
- The result is only visible on the card ([`markets/_bet_panel.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_bet_panel.html.erb): "You called it! …") and on the wallet page.
- [`layouts/_nav.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/layouts/_nav.html.erb) shows the balance pill in `.topbar__account`.

## Suggested implementation
1. Migration `create_notifications`: `user`, `market`, and `bet` references (all `null: false` with foreign keys; `bet` with a unique index, `user` with `index: false`), `kind` string `null: false`, `read_at` datetime, timestamps. Add `add_index :notifications, [ :user_id, :read_at ]` and a check constraint `kind IN ('won', 'lost', 'refunded', 'cancelled')`, like `bets_status_check`.
2. New model `Notification`: `belongs_to :user`, `belongs_to :market`, `belongs_to :bet`; `enum :kind, { won: "won", lost: "lost", refunded: "refunded", cancelled: "cancelled" }, validate: true`; `scope :unread, -> { where(read_at: nil) }`. `User` gets `has_many :notifications, dependent: :delete_all`.
3. In `Markets::Resolve#perform`, after `@market.update!`, still inside the transaction:
   ```ruby
   Notification.insert_all(bets.map { |bet| { user_id: bet.user_id, market_id: @market.id, bet_id: bet.id, kind: bet.status } })
   ```
   After `settle`, `bet.status` already holds won/lost/refunded. `Markets::Cancel` does the same with `kind: "cancelled"`. `insert_all` fills timestamps, is a no-op for an empty array in Rails 8.1, and rolls back with a failed settlement.
4. `resources :notifications, only: :index` and a new `NotificationsController#index`: load the latest 50, newest first, `includes(market: :winning_outcome, bet: :outcome)`, into an array, then `Current.user.notifications.unread.update_all(read_at: Time.current)` so the view can still highlight what was new.
5. Partial `notifications/_notification.html.erb`, copy mirroring `_bet_panel`, each linking to `market_path`:
   - won: "You called it! **Swish** paid 126 credits on “Will the free throw go in?”"
   - lost: "You picked **Brick** and lost 50 credits on “…”. Result: Swish."
   - refunded: "No contest on “…”: your 50 credits were refunded."
   - cancelled: "“…” was cancelled and your 50 credits were refunded."
6. Nav: a bell link before the balance pill with `<span class="visually-hidden">Notifications</span>` and a `#notification-count` badge showing `Current.user.notifications.unread.count` when positive. Add `data: { turbo_prefetch: false }`: Turbo 8 prefetches links on hover, which would mark everything read before the click.
7. Optional live badge: `turbo_stream_from Current.user, :notifications` in the nav, broadcast from the services inside `ActiveRecord.after_all_transactions_commit { … }`. Signed-in users can already open cable connections.

## Acceptance criteria
- [ ] Resolving or cancelling a market creates exactly one notification per bet with the right kind, and none for anyone else; a failed settlement creates none.
- [ ] The nav shows the unread count; `/notifications` lists them newest first and clears the count.
- [ ] RSpec: `spec/services/markets/resolve_spec.rb` (won/lost kinds, no-contest gives refunded, no bets gives none), `spec/services/markets/cancel_spec.rb` (cancelled), `spec/models/notification_spec.rb`, `spec/requests/notifications_spec.rb` (sign-in required, only your own, marks read).
- [ ] Cucumber `features/wallet/notifications.feature`: after "Will the free throw go in?" settles as "Swish", I have 1 unread notification, open my notifications, see "You called it!", and the count is gone. Add "my notifications" to `features/support/paths.rb` and the `{page}` regexp in `parameter_types.rb`.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. The optional live badge should reuse the broadcasting pattern from #7 (Stream live pool and odds updates to every viewer). Settlements from #20 (Admin role with moderation tools) go through the same services, so they notify too.
- **Out of scope:** email or push notifications, creator-reward notifications, notification settings.
- **Size:** M (1–2 days)
