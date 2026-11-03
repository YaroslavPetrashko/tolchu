---
title: "Accessibility audit of the feed, bet form, and studio"
labels: ["type: chore", "area: frontend", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
Make the feed, market page, studio, wallet, and sign-up/sign-in usable with a keyboard, a screen reader, and reduced-motion settings, with a Lighthouse accessibility score of at least 95, before real-user testing.

## Context
Contrast measured from the tokens in [`application.css`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/assets/stylesheets/application.css):
- Already passing: `--muted` (#a1a1b5) is 7.1:1 on `--surface`, 6.5:1 on `--surface-2`, and 4.6:1 on the purple share bar, so muted text and the small uppercase labels (`.stake-input label`, `.settlement dt`, `.wallet-stats dt`, `.data-table th`) meet AA.
- Failing: `.badge--open` ("Live") is white on #fb7185, 2.7:1. `.btn--primary` is white on #8b5cf6 at the gradient start, 4.2:1, and on #9b74f8 on hover, 3.4:1.

Other findings:
- Focus: `input:focus { outline: none; box-shadow: 0 0 0 3px rgb(139 92 246 / 0.3) }` outranks the global `:focus-visible` outline for every input. On the outcome radios that glow is 1.4:1 against the background, so keyboard focus on an outcome is effectively invisible. `.chip` and `.icon-btn` keep the global outline.
- Motion: [`clip_controller.js`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/javascript/controllers/clip_controller.js) autoplays at 60% visibility and plays full clips after settlement, but offers only replay and mute, no pause (WCAG 2.2.2; one seeded clip runs 8 s before its freeze). `.flash` animates in.
- [`countdown_controller.js`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/javascript/controllers/countdown_controller.js) rewrites the countdown every second and is correctly not a live region.
- Forms: [`shared/_form_errors`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/shared/_form_errors.html.erb) is a `role="alert"` summary, but fields get no `aria-invalid` or `aria-describedby`.
- Structure: the feed has no `<h1>`, there's no skip link to `<main id="main">`, active nav links rely on `.is-active`, outcome radios have no `<fieldset>`, and stake chips are bare numbers with no pressed state. Video `aria-label`s and `th scope` are fine.

## Suggested implementation
1. Colors: `.badge--open { color: #1a0309 }` (7.4:1) or a #be123c background (6.3:1 with white); start `.btn--primary` at #7c3aed (5.7:1) and never go lighter on hover.
2. Focus: limit the glow rule to text-like inputs (`input:not([type="radio"], [type="checkbox"])`) and add `.outcome--selectable:has(.outcome__radio:focus-visible) { outline: 3px solid var(--accent-2); outline-offset: 2px; }`, since the label's `::after` covers the row.
3. Motion: skip autoplay when `matchMedia("(prefers-reduced-motion: reduce)").matches` (label the replay button "Play clip" until it has played), add a play/pause toggle for everyone, and disable animations and transitions under `@media (prefers-reduced-motion: reduce)`.
4. Announcements: keep the ticking label silent; add a visually hidden `role="status"` per card that `countdown#lock` fills once with "Betting closed"; make `.bet-form__estimate` `aria-live="polite"`.
5. Forms: an initializer setting `ActionView::Base.field_error_proc` to add `aria-invalid="true"` instead of the unstyled `field_with_errors` wrapper; give the error summary an id and point `aria-describedby` at it.
6. Structure: visually hidden `<h1>` on the feed, a skip link, `aria-current="page"` in `_nav.html.erb`, a `<fieldset>` with a visually hidden `<legend>` (the question) around selectable outcomes, and chips with `aria-label="Stake 10 credits"` and `aria-pressed` toggled in `stake#highlightChips`.
7. Manual pass with VoiceOver on iOS Safari and with the keyboard alone on every page above; list the findings in the PR.

## Acceptance criteria
- [ ] Lighthouse accessibility ≥ 95 on `/`, a market page, `/studio/markets/new`, `/wallet`, `/sign_up`, and `/sign_in` (run by hand until #4 automates it).
- [ ] All text pairs above reach 4.5:1, and every focusable element has a visible indicator of at least 3:1.
- [ ] With reduced motion on, no clip autoplays and nothing animates; any playing clip can be paused.
- [ ] RSpec: request specs for `aria-invalid` after a failed sign-up, `aria-current` in the nav, and the fieldset/legend in the bet form.
- [ ] Cucumber: after a failed sign-up, the "Password" field is marked invalid (rack_test can read `aria-invalid`).
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing to start. #4 (Run Lighthouse CI against production and review apps) gates the score; #12 (Browser-level Cucumber scenarios for the clip player, countdown, and stake estimate) enables axe checks. Coordinate with #14's dialog and #38 (Keyboard and swipe navigation between clips).
- **Out of scope:** captions (the clips have no speech), a light theme, redesigning components.
- **Size:** M (1–2 days)
