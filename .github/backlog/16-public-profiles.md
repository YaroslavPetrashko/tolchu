---
title: "Public profiles with prediction stats"
labels: ["type: feature", "area: frontend", "area: backend", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
As a fan, I want to tap any @username and see that person's prediction record, so I can judge whose clips are worth my credits and show off my own calls. It also gives creators an identity beyond a byline.

## Context
- Usernames are plain text today: the card byline `@<%= market.creator.username %> asks` ([`markets/_market.html.erb#L29`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_market.html.erb#L29)), "Posted by @…" ([`markets/show.html.erb#L39`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/show.html.erb#L39)), and "@username · Balance" ([`wallets/show.html.erb#L7`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/wallets/show.html.erb#L7)).
- [`Bet`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/bet.rb) has `status` pending/won/lost/refunded and a `payout` set at settlement (`Bet#net` is payout minus stake). Usernames are unique ignoring case through `index_users_on_lower_username` ([`db/schema.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/db/schema.rb)).
- [`WalletsController#show`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/wallets_controller.rb) computes similar numbers in Ruby, privately, for the signed-in user only.

## Suggested implementation
1. Route: `get "@:username", to: "profiles#show", as: :profile, constraints: { username: /[A-Za-z0-9_]+/ }`, giving `/@StuntLab`. Build links with `profile_path(user.username)`.
2. New `ProfilesController#show` with `allow_unauthenticated_access only: :show`. Find the user with `User.where("lower(username) = ?", params[:username].downcase).first!` (uses the functional index; unknown names 404).
3. New PORO `app/models/profile_stats.rb` (same style as `MarketFeed`), one aggregate query for the numbers:
   ```ruby
   predictions, won, lost, net = user.bets.pick(
     Arel.sql("COUNT(*)"),
     Arel.sql("COUNT(*) FILTER (WHERE status = 'won')"),
     Arel.sql("COUNT(*) FILTER (WHERE status = 'lost')"),
     Arel.sql("COALESCE(SUM(payout - stake) FILTER (WHERE status IN ('won', 'lost')), 0)")
   )
   ```
   - `win_rate` = won / (won + lost), `nil` when nothing has settled (render "—"). Refunded bets count as predictions but never toward win rate or profit.
   - `markets_created` = `user.created_markets.count`.
   - `recent_settled` = the last 10 won/lost bets: `user.bets.where(status: %w[won lost]).joins(:market).includes(:outcome, :market).order("markets.resolved_at DESC").limit(10)`.
4. View `profiles/show.html.erb` reusing the wallet styles (`.wallet-stats`, `.bet-list`) and helpers (`percent`, `signed_credits`, `bet_status_label`). Show only public information: no email, no balance, and no pending predictions (an open position on a live pool is nobody else's business and could sway it).
5. Link usernames to profiles in the card byline, the "Posted by" line, and the wallet header.

Gotcha: [`spec/requests/markets_spec.rb#L15`](https://github.com/YaroslavPetrashko/tolchu/blob/main/spec/requests/markets_spec.rb#L15) asserts the raw HTML includes "@StuntLab asks". With the link the markup becomes `<a …>@StuntLab</a> asks`, so update that expectation. The Cucumber step `the market … should say "@StuntLab asks"` compares page text and keeps passing.

## Acceptance criteria
- [ ] `/@username` works for guests and for any capitalization of the name; unknown names return 404.
- [ ] The page shows predictions, settled count, win rate (refunds excluded), net profit (won and lost only), markets created, and the last 10 settled predictions.
- [ ] It never shows the email address, balance, or pending predictions.
- [ ] Bylines, "Posted by", and the wallet header link to the profile.
- [ ] RSpec: `spec/models/profile_stats_spec.rb` (a user with won, lost, refunded, and pending bets; a user with no settled bets has a `nil` win rate); `spec/requests/profiles_spec.rb` (guest access, case-insensitive lookup, 404, no email or balance in the body).
- [ ] Cucumber `features/feed/profiles.feature`: following "@StuntLab" from a card opens a profile showing "Markets created"; a bettor with one win, one loss, and one refund shows a 50% win rate.
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. #17 (Weekly leaderboard of top predictors) and #34 (Follow creators and a Following feed) link to these pages.
- **Out of scope:** avatars, bios, editing usernames, creator earnings (that's #11, Creator earnings dashboard).
- **Size:** M (1–2 days)
