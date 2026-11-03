---
title: "Admin role with moderation tools"
labels: ["type: feature", "area: backend", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
As a team member running the final demo and real-user testing, I want an admin area to settle or cancel any market and suspend abusive accounts, so we can fix a stuck or inappropriate market without opening a production Rails console.

## Context
- Only a market's creator can lock, resolve, or cancel it: [`Studio::MarketsController#set_market`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/studio/markets_controller.rb) scopes to `Current.user.created_markets` (anyone else gets 404). The state changes live in `Markets::Lock`, `Markets::Resolve`, and `Markets::Cancel` ([`app/services/markets/`](https://github.com/YaroslavPetrashko/tolchu/tree/main/app/services/markets)).
- [`MarketFeed`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/market_feed.rb) already leaves cancelled markets out, so cancelling doubles as a takedown (with full refunds).
- `users` has no role or status columns. Sign-in is [`SessionsController#create`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/sessions_controller.rb) (`User.authenticate_by`); bets go through [`Betting::PlaceBet`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/betting/place_bet.rb). Sign-up permits only username, email, and passwords ([`RegistrationsController`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/registrations_controller.rb)).

## Suggested implementation
1. Migration: `add_column :users, :admin, :boolean, null: false, default: false` and `add_column :users, :suspended_at, :datetime`. Add `User#suspended?`. Never add `:admin` to any permitted params.
2. `lib/tasks/users.rake` with `users:grant_admin[email]` and `users:revoke_admin[email]` (`User.find_by!(email_address: args[:email])`). On Heroku, quote the brackets for zsh: `heroku run "bin/rails 'users:grant_admin[you@example.com]'" -a tolchu`.
3. New `app/controllers/admin/base_controller.rb`:
   ```ruby
   module Admin
     class BaseController < ApplicationController
       before_action :require_admin

       private
         # 404 rather than 403, so the admin area isn't discoverable.
         def require_admin
           raise ActiveRecord::RecordNotFound unless Current.user&.admin?
         end
     end
   end
   ```
4. Routes: `namespace :admin` with `resources :markets, only: :index` (member `patch :lock`, `:resolve`, `:cancel`) and `resources :users, only: :index` (member `patch :suspend`, `:unsuspend`).
5. `Admin::MarketsController`: all markets, newest first, `includes(:creator, :outcomes, :winning_outcome)`, with phase badge, creator, and pool. Member actions call the same services as Studio and redirect with the result (extract Studio's `redirect_with` into a small concern rather than copying it). Don't render `studio/markets/_market` here: its forms post to `studio_*` routes.
6. `Admin::UsersController`: list users with balance and status. `suspend` sets `suspended_at` and runs `user.sessions.destroy_all` (signed out everywhere); refuse to suspend yourself or another admin. `unsuspend` clears `suspended_at`.
7. Enforcement: `SessionsController#create` redirects a suspended user to sign-in with "This account is suspended."; `Betting::PlaceBet#perform` starts with `fail!("Your account is suspended") if @user.suspended?` as defense in depth.
8. Nav: an "Admin" link in `_nav.html.erb`, only when `Current.user&.admin?`.

## Acceptance criteria
- [ ] Guests are sent to sign in; signed-in non-admins get 404 on every `/admin` route; admins see the markets and users lists.
- [ ] Admins can lock, resolve, and cancel any market, with payouts and refunds identical to the Studio path.
- [ ] Suspended users are signed out, can't sign in, and can't bet; unsuspending restores access.
- [ ] Posting `user[admin]=1` to sign-up doesn't create an admin.
- [ ] RSpec: `spec/requests/admin/markets_spec.rb` and `spec/requests/admin/users_spec.rb` (guest, user, and admin for every route; each action); suspended cases in `spec/requests/sessions_spec.rb` and `spec/services/betting/place_bet_spec.rb`; `spec/requests/registrations_spec.rb` (admin param ignored); a rake task spec in the style of [`lock_expired_spec.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/spec/services/markets/lock_expired_spec.rb), because `.simplecov` only skips `cucumber.rake`.
- [ ] Cucumber `features/admin/moderation.feature`: an admin cancels another creator's market and every bettor is refunded; a suspended user sees "This account is suspended." when signing in.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Once #15 (Notify bettors when their prediction settles) lands, admin settlements notify bettors automatically because they use the same services. #32 (Let bettors dispute a result) will build on this area.
- **Out of scope:** an audit log, editing markets (#39), finer-grained roles, admin credit grants.
- **Size:** L (3+ days)
