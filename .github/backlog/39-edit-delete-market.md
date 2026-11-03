---
title: "Edit or delete a market before anyone bets"
labels: ["type: feature", "area: creator-tools", "priority: P3 · backlog"]
---
## Summary
As a creator who spots a typo, a wrong freeze point, or a broken clip link right after publishing, I want to edit or delete the market while nobody has bet on it, so I don't have to cancel it and post a duplicate.

## Context
- [`Studio::MarketsController`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/studio/markets_controller.rb) has `index/new/create` plus member `lock/resolve/cancel`; `set_market` scopes to `Current.user.created_markets`. [`config/routes.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/routes.rb) declares `only: %i[index new create]`.
- [`Market`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/market.rb): `accepts_nested_attributes_for :outcomes, reject_if: ->(attributes) { attributes["label"].blank? }` (no `allow_destroy`); `apply_betting_window` and `locks_at_must_be_in_the_future` run only on create; `outcome_count_within_limits` already skips `marked_for_destruction?`; `has_many :bets, dependent: :restrict_with_error`; `bets_count` is a counter cache.
- [`Betting::PlaceBet`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/services/betting/place_bet.rb) locks the market row before saving a bet, so an edit under the same lock can't interleave with one.
- Form: [`studio/markets/new.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/studio/markets/new.html.erb); per-phase actions: [`studio/markets/_market.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/studio/markets/_market.html.erb).

## Suggested implementation
1. `Market#editable?(now = Time.current)`: `accepting_bets?(now) && bets_count.zero?`.
2. Services (new) `Markets::Update` (`market:`, `attributes:`) and `Markets::Destroy` (`market:`): inside `Market.transaction`, `@market.lock!` (which reloads, so the check sees a bet committed a moment ago), `fail!("Someone already predicted on this market, so it can't be changed") unless @market.editable?`, then `assign_attributes` + `save` (fail with the record's errors) or `destroy` (a `false` from `restrict_with_error` also fails).
3. Model:
   - `accepts_nested_attributes_for :outcomes, allow_destroy: true, reject_if: ->(attributes) { attributes["id"].blank? && attributes["label"].blank? }`: blank new slots stay ignored, but clearing an existing label now shows "Outcome can't be blank" instead of being silently skipped.
   - Run `apply_betting_window` on update too (drop `on: :create`). The virtual `betting_window_minutes` is blank unless a window is picked again, so `locks_at` only moves when re-chosen.
   - Make `outcome_labels_must_be_unique` skip outcomes marked for destruction, so replacing "Yes" with "yes" isn't a false duplicate.
4. Controller and routes: `only: %i[index new create edit update destroy]`; add the three actions to `set_market`; permit `outcomes_attributes: [ [ :id, :label, :_destroy ] ]`. `edit` and a failed `update` call `build_blank_outcomes`. Success redirects to the studio with `status: :see_other` ("Saved." / "“…” was deleted."); a refused change redirects with the service error.
5. Views: extract `studio/markets/_form.html.erb` from `new.html.erb` (url and submit label as locals). On edit, existing outcomes get a "Remove" checkbox (`_destroy`) and the window select gets `include_blank: "Keep the current deadline"`. In the studio card's `:open` branch, show "Edit" and "Delete" (`turbo_confirm`) when `market.editable?`, else disabled buttons with "Locked after the first prediction".

## Acceptance criteria
- [ ] With no bets, a creator can change the question, description, clip URL, freeze point, and outcomes (add, rename, remove, staying within 2–4), or delete the market
- [ ] `locks_at` changes only when a new window is picked
- [ ] After the first bet, or once locked or settled, edit and delete are refused by the controller, the service, and the model (`market.destroy` returns false with an error when bets exist)
- [ ] Another creator's market returns 404
- [ ] RSpec: `spec/requests/studio/markets_spec.rb` (edit, update, destroy; with a bet; locked; other creator), `spec/services/markets/update_spec.rb`, `spec/services/markets/destroy_spec.rb`, `spec/models/market_spec.rb` (`editable?`, `_destroy`, the new `reject_if`, `restrict_with_error`)
- [ ] Cucumber `features/studio/edit_market.feature`: "Fixing a typo before anyone bets"; "Deleting a market nobody bet on"; "Editing is locked after the first prediction"
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. If #27 (The full clip is downloadable before betting locks, so the ending can be watched early) has landed, a changed clip or `freeze_at` must re-cut the setup clip.
- **Out of scope:** editing after bets (with refunds), edit history.
- **Size:** M
