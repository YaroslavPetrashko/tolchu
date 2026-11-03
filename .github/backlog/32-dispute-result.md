---
title: "Let bettors dispute a result"
labels: ["type: feature", "area: creator-tools", "area: backend", "priority: P3 · backlog"]
---
## Summary
As a bettor who saw a creator declare the wrong result, I want to report it within 24 hours, so an admin can review it and creators with a record of bad calls become visible. Today a resolution is final and nothing records disagreement.

## Context
- [`Markets::Resolve`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/markets/resolve.rb) pays out once and refuses to run again; [`Market`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/market.rb) keeps `resolved_at`, `winning_outcome`, and `refunded`.
- [`markets/show.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/show.html.erb) shows the settlement (`if @market.resolved?`) with no follow-up action; [`MarketsController#show`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/markets_controller.rb) already loads `@viewer_bet` via `User#bet_on`.
- Admins arrive with #20, public profiles with #16.

## Suggested implementation
1. Migration (new), in the style of `create_bets`:
```ruby
create_table :disputes do |t|
  t.references :market, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true, index: false
  t.text :reason, null: false
  t.string :status, null: false, default: "open"
  t.datetime :reviewed_at
  t.timestamps
end
add_index :disputes, [ :user_id, :market_id ], unique: true
add_check_constraint :disputes, "status IN ('open', 'upheld', 'dismissed')", name: "disputes_status_check"
```
2. `Dispute` (new): `WINDOW = 24.hours`; `belongs_to :market`, `belongs_to :user`; `enum :status, { open: "open", upheld: "upheld", dismissed: "dismissed" }, default: :open, validate: true`; `reason` required, at most 500 characters; `user_id` unique per `market_id` ("You already reported this result"). On create, the market must be resolved, `Time.current < resolved_at + WINDOW`, and the user must have a bet on it (no-contest refunds are disputable too). Add `has_many :disputes` to `Market` and `User`, and `Market#disputable_by?(user, now: Time.current)` for the view.
3. `DisputesController#create` (new), signed-in only, routed by `resources :disputes, only: :create` inside `resources :markets`: `Current.user.disputes.build(market: @market, reason:)`, then redirect to the market with "Thanks. An admin will review this result." or the errors as an alert.
4. `markets/show.html.erb`, below the settlement: if `@market.disputable_by?(Current.user)`, a `<details>` "Report a wrong result" containing `form_with model: [ @market, Dispute.new ]` (the controller reads `params.expect(dispute: [ :reason ])`), a `reason` textarea (`maxlength: 500`), and "Send report". If the viewer already reported: "You reported this result (open/upheld/dismissed)".
5. With #20: `Admin::DisputesController` `index` (open first: question, declared result, reporter, reason, age) and `update` (sets `status` and `reviewed_at`), behind #20's admin guard. Reviewing never moves credits.
6. With #16: `User#upheld_disputes_count` = `Dispute.upheld.joins(:market).where(markets: { creator_id: id }).distinct.count(:market_id)`, shown on the creator's profile as "Disputed results upheld: N".

## Acceptance criteria
- [ ] A bettor on a resolved market can file one dispute until 24 hours after `resolved_at`; after the window, without a bet, or as a guest, the form is absent and a forged POST is rejected
- [ ] Filing changes no balances, bets, or market fields
- [ ] Admins list open disputes and mark them upheld or dismissed; non-admins get 404
- [ ] The creator's profile shows how many of their markets have an upheld dispute
- [ ] RSpec: `spec/models/dispute_spec.rb` (window edges via `travel_to`, bettors only, one per user and market, reason length, status check constraint), `spec/requests/disputes_spec.rb`, admin request spec once #20 is in
- [ ] Cucumber `features/betting/dispute_result.feature`: "Reporting a wrong result within a day"; "The report option disappears after 24 hours" (add `{int} hour(s) pass` next to the minutes step in `web_steps.rb`); "Only bettors can report a result"
- [ ] `bin/ci` passes

## Notes
- **Depends on:** #20 (Admin role with moderation tools) for step 5 and #16 (Public profiles with prediction stats) for step 6; steps 1–4 need neither.
- **Out of scope:** reversing payouts (winners may have spent the credits), notifying creators, disputing cancelled markets.
- **Size:** M
