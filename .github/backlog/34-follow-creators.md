---
title: "Follow creators and a Following feed"
labels: ["type: feature", "area: frontend", "area: backend", "priority: P3 · backlog"]
---
## Summary
As a viewer who likes a creator's clips, I want to follow them and open a Following tab with only their markets, so I come back for the creators I trust.

## Context
- The byline is `<p class="clip-card__byline">@<%= market.creator.username %> asks</p>` in [`markets/_market.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_market.html.erb). The same partial renders on the feed, the market page, and in `BetsController#render_card_update`'s Turbo Stream.
- [`User`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/user.rb) has `created_markets` and no social graph.
- [`MarketFeed`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/market_feed.rb) takes a `viewer`; #33 adds the `tab` param and tab bar; #16 adds profile pages.

## Suggested implementation
1. Migration (new):
```ruby
create_table :follows do |t|
  t.references :follower, null: false, foreign_key: { to_table: :users }, index: false
  t.references :creator, null: false, foreign_key: { to_table: :users }
  t.timestamps
end
add_index :follows, [ :follower_id, :creator_id ], unique: true
add_check_constraint :follows, "follower_id <> creator_id", name: "follows_not_self"
```
2. `Follow` (new): `belongs_to :follower, class_name: "User"`, `belongs_to :creator, class_name: "User"`, `validates :creator_id, uniqueness: { scope: :follower_id }`, and an error "You can't follow yourself". On `User`: `has_many :follows, foreign_key: :follower_id, inverse_of: :follower, dependent: :destroy`, `has_many :followed_creators, through: :follows, source: :creator`, the reverse pair (`creator_follows`, `followers`), and `following?(user)`.
3. Routes: `resources :users, only: [] do resource :follow, only: %i[create destroy] end` (`user_follow_path(creator)`). `FollowsController` (new, signed-in only): `create` does `Current.user.follows.find_or_create_by!(creator:)`, treating `ActiveRecord::RecordNotUnique` as success and a self-follow as an alert; `destroy` deletes the row. One creator can have several cards on the feed, so answer with `turbo_stream.replace_all("[data-follow-creator='#{creator.id}']", partial: "follows/button", locals: { creator: })`; HTML fallback `redirect_back fallback_location: root_path`.
4. `follows/_button.html.erb` (new): a `<span data-follow-creator="<%= creator.id %>">` wrapping `button_to` "Follow" (POST) or "Following" (DELETE), so the stream swaps the whole form, not just the button. Render it when `Current.user` exists and isn't the creator, next to the byline and on the profile (#16). `button_to` renders a `<form>`, which can't sit inside a `<p>`, so make the byline a `<div>`. Avoid a query per card: `MarketFeed#following?(creator)` backed by `viewer.follows.pluck(:creator_id).to_set`.
5. Following tab (extends #33): `tab=following`, shown only when signed in; `MarketFeed` filters with `where(creator_id: viewer.follows.select(:creator_id))`; guests asking for it get All. Empty state: "Follow creators to see their clips here."

## Acceptance criteria
- [ ] Following or unfollowing from a card updates every card by that creator without a reload; guests see no button, and a forged POST redirects to sign-in
- [ ] Users can't follow themselves (no button on their own markets; model and database reject it); duplicate follows are impossible
- [ ] The Following tab lists only followed creators' markets, in feed order
- [ ] RSpec: `spec/models/follow_spec.rb` (uniqueness, self-follow, check constraint), `spec/requests/follows_spec.rb` (create, destroy, `replace_all` stream, guest redirect, self-follow), `spec/models/market_feed_spec.rb` (following tab, guest fallback)
- [ ] Cucumber `features/feed/follow_creators.feature`: "Following a creator from their clip"; "The Following tab shows only creators I follow"; "Unfollowing removes their clips from Following"; "There's no follow button on my own clips" (new step `When I press {string} on {string}`, scoped with `card_for`)
- [ ] `bin/ci` passes

## Notes
- **Depends on:** #33 (Feed filters: Closing soon, Sports, Stunts) for the tab; #16 (Public profiles with prediction stats) for the profile button only.
- **Out of scope:** follower counts on cards, notifications about new markets, blocking.
- **Size:** M
