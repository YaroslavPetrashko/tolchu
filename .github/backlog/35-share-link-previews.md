---
title: "Share a clip with rich link previews"
labels: ["type: feature", "area: frontend", "priority: P3 · backlog"]
---
## Summary
As a viewer I want to share a clip and have the link unfurl with its question and pool in iMessage, WhatsApp, Slack, Discord, and X, so friends tap through and predict. Shared links are our cheapest growth loop.

## Context
- [`markets/show.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/show.html.erb) sets `content_for :title, @market.question`. The layout ([`application.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/layouts/application.html.erb)) already has `yield :head` and one generic `<meta name="description">`. There are no Open Graph or Twitter tags, and the only images in `public/` are the placeholder `icon.png`/`icon.svg`.
- Cards ([`markets/_market.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_market.html.erb)) have icon buttons in `.clip-card__controls` (replay, sound).
- [`ApplicationController`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/application_controller.rb) calls `allow_browser versions: { safari: 16.4, chrome: 108, firefox: 108, opera: 94, ie: false }`. Verified on production (Nov 3): Slackbot gets 200, but iMessage's preview fetcher (`… Version/9.0.1 Safari/601.2.4 facebookexternalhit/1.1 Facebot Twitterbot/1.0`) parses as Safari 9 and gets the 406 page, so iMessage can't unfurl links.

## Suggested implementation
1. In `markets/show.html.erb`, add a `content_for :head` block of `tag.meta` calls (they escape the question):
   - `og:type` website, `og:site_name` Tolchu, `og:title` the question, `og:url` `market_url(@market)`, plus `<link rel="canonical">` with the same URL
   - `og:description`, e.g. "Live · 120 credits in the pool · 3 predictions. What happens next?", from `phase_label`, `credits`, and `pluralize`
   - `og:image` `image_url("/og-card.png")` (absolute), with `og:image:width`/`height`: a new static 1200×630 branded PNG in `public/`, until #9 (Let creators upload clips instead of pasting a URL) provides poster frames
   - `twitter:card` summary_large_image (X falls back to the og:* tags for the rest)
   Don't add `og:video` with the clip URL: it would hand out the ending (#27).
2. Exempt link-preview fetchers from the browser guard by adding `unless: -> { request.user_agent.to_s.match?(/facebookexternalhit|Facebot|Twitterbot/) }` to the existing `allow_browser` call (it accepts the usual `before_action` options).
3. `app/javascript/controllers/share_controller.js` (new):
```js
static values = { url: String, title: String }

async share() {
  const data = { title: this.titleValue, text: `${this.titleValue} Call it on Tolchu.`, url: this.urlValue }
  if (navigator.share) {
    try { return await navigator.share(data) } catch (error) { if (error.name === "AbortError") return }
  }
  await navigator.clipboard.writeText(this.urlValue)
  this.element.setAttribute("aria-label", "Link copied")
  this.element.classList.add("is-copied") // CSS shows a brief "Copied" label
}
```
4. In `.clip-card__controls`, a `<button type="button" class="icon-btn" aria-label="Share clip" data-controller="share" data-action="share#share" data-share-url-value="<%= market_url(market) %>" data-share-title-value="<%= market.question %>">`. It then appears on the feed, the market page, and stream-replaced cards.

## Acceptance criteria
- [ ] `GET /markets/:id` has og:title, og:description, og:url, an absolute og:image, the canonical link, and twitter:card, with the question escaped
- [ ] A request with iMessage's preview user agent gets 200 and the tags
- [ ] On phones Share opens the native sheet; where `navigator.share` is missing (e.g. desktop Firefox) the link is copied and the button says so
- [ ] RSpec: `spec/requests/markets_spec.rb` with `assert_select "meta[property='og:title'][content=?]", market.question` and the other tags, the iMessage user-agent example, and the share button's `data-share-url-value`
- [ ] Checked with Facebook's Sharing Debugger and a real Slack and iMessage paste on a review app (screenshots in the PR)
- [ ] Cucumber: none until #12 (Browser-level Cucumber scenarios for the clip player, countdown, and stake estimate)
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. #27 (The full clip is downloadable before betting locks, so the ending can be watched early) explains the `og:video` rule.
- **Out of scope:** per-market generated images, short links, share counts.
- **Size:** S
