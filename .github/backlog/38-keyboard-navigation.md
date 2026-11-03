---
title: "Keyboard and swipe navigation between clips"
labels: ["type: feature", "area: frontend", "priority: P3 · backlog"]
---
## Summary
As a desktop viewer I want ↓/↑ (or j/k) to jump between clips, m to toggle sound, and r to replay, so the feed feels like a short-video app without a touchscreen. Touch swipe already works through CSS scroll snapping; keyboard users have no equivalent.

## Context
- [`markets/index.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/index.html.erb) renders cards inside `.feed`, the scroll container (`overflow-y: auto; scroll-snap-type: y mandatory` in [`application.css`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/assets/stylesheets/application.css)); `body.is-feed` has `overflow: hidden`, so the window never scrolls. Each `.clip-card` is one screen tall with `scroll-snap-align: start`.
- [`clip_controller.js`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/javascript/controllers/clip_controller.js) controls playback per card (`data-controller="clip countdown"` in [`_market.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_market.html.erb)) and already has `toggleSound()` and `replay()`.
- stimulus-rails 1.3.4 vendors Stimulus 3.2.2, so outlets are available.

## Suggested implementation
1. `app/javascript/controllers/feed_controller.js` (new) on `.feed`: `data-controller="feed" data-action="keydown@window->feed#navigate" data-feed-clip-outlet=".clip-card"`. Give each card `data-feed-target="card"` in `_market.html.erb` (harmless on the market page, which has no feed controller).
```js
static targets = ["card"]
static outlets = ["clip"]

navigate(event) {
  if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey) return
  if (event.target.closest("input, select, textarea, [contenteditable]")) return
  const handler = { ArrowDown: () => this.move(1), j: () => this.move(1), ArrowUp: () => this.move(-1),
                    k: () => this.move(-1), m: () => this.currentClip?.toggleSound(), r: () => this.currentClip?.replay() }[event.key]
  if (!handler) return
  event.preventDefault() // keep the browser's own arrow-key scroll from fighting the snap
  handler()
}
```
2. `currentCard`: the card target whose `getBoundingClientRect().top` is closest to the feed's top. `currentClip`: `this.clipOutlets.find((clip) => clip.element === this.currentCard)`. `move(step)`: scroll the neighbouring card with `scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "start" })`, where `reduceMotion` is `matchMedia("(prefers-reduced-motion: reduce)").matches`; do nothing past the first or last card.
3. After moving, focus the card without scrolling (`tabindex="-1"` on the article, `focus({ preventScroll: true })`) so Tab continues inside the visible clip.
4. Hint: `<p class="feed-hint">↑ ↓ or J K to move · M sound · R replay</p>` in `index.html.erb`, fixed bottom-left, hidden by default and shown only under `@media (hover: hover) and (pointer: fine)`.
5. Swipe needs no code. Check on one iPhone and one Android phone that a swipe moves exactly one card, and note it in the PR.
6. Cards added later (by #29's infinite scroll or Turbo Stream replacements) become targets and outlets automatically.

## Acceptance criteria
- [ ] ↓/j and ↑/k move exactly one card (smoothly, or instantly with reduced motion); m and r act on the visible clip
- [ ] Keys do nothing while typing in the stake input or a studio field, or with Cmd/Ctrl/Alt held
- [ ] The hint shows on desktop, not on touch devices
- [ ] RSpec: `spec/requests/markets_spec.rb` asserts the feed renders `data-controller="feed"`, the clip outlet, card targets, and the hint
- [ ] Cucumber: once #12 lands, "Moving to the next clip with the keyboard" and "Typing a stake doesn't move the feed"
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Browser tests need #12 (Browser-level Cucumber scenarios for the clip player, countdown, and stake estimate); review the key choices with #25 (Accessibility audit of the feed, bet form, and studio); step 6 covers cards appended by #29 (Infinite scroll for the feed).
- **Out of scope:** horizontal swipes, a shortcuts help dialog.
- **Size:** S
