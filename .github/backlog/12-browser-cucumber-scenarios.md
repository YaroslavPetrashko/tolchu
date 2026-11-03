---
title: "Browser-level Cucumber scenarios for the clip player, countdown, and stake estimate"
labels: ["type: test", "area: frontend", "priority: P1 · iteration 2"]
milestone: "Iteration 2"
---
## Summary
Run a few Cucumber scenarios in a real headless browser so CI covers the JavaScript at the core of the product: freezing before the action, the client-side lock, the payout estimate, and in-place bet updates. Today these are only checked by hand.

## Context
- **No browser driver yet.** Capybara only runs `rack_test`, and the [`Gemfile`](https://github.com/YaroslavPetrashko/tolchu/blob/main/Gemfile) has no `selenium-webdriver`. [`features/support/env.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/features/support/env.rb) already sets `Cucumber::Rails::Database.javascript_strategy = :truncation`.
- **The JavaScript under test** lives in [`app/javascript/controllers/`](https://github.com/YaroslavPetrashko/tolchu/tree/main/app/javascript/controllers):
  - `clip_controller.js` autoplays a card once 60% of it is visible, pauses at `freezeAt` (via `requestVideoFrameCallback`, with `timeupdate` as fallback), and adds `is-frozen`.
  - `countdown_controller.js` sets the label to "Betting closed" at zero and disables the submit button, changing its value to "Betting closed".
  - `stake_controller.js` fills `Stake` from the chips and writes "If you're right: about N credits back (×M)."
- **Video URLs.** `Market#video_url` must match `\A(https?://|/)\S+\z`. The factory's fake CDN URL can't be played by a real browser.
- **Reusable helpers** in [`features/support/world.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/features/support/world.rb): `sign_in_as`, `post_market`, `card_for`, `submit_prediction`.

## Suggested implementation
1. Add `gem "selenium-webdriver"` to the `:test` group. Selenium Manager downloads a matching chromedriver, and GitHub's `ubuntu-latest` runners already have Chrome.
2. Add `features/support/javascript_driver.rb` (new):

```ruby
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  %w[headless=new autoplay-policy=no-user-gesture-required mute-audio window-size=430,932].each do |arg|
    options.add_argument("--#{arg}")
  end
  Capybara::Selenium::Driver.new(app, browser: :chrome, options:)
end
Capybara.javascript_driver = :headless_chrome
Capybara.default_max_wait_time = 5
```
3. **Test clip.** Generate a small file:
   `ffmpeg -f lavfi -i testsrc=duration=3:size=320x240:rate=30 -c:v libx264 -pix_fmt yuv420p -movflags +faststart spec/fixtures/files/clip.mp4`
   It's a few KB and shared with #9. Serve it in the test environment only, with HTTP range support for seeking, by adding this to `config/routes.rb`:
   `mount Rack::Files.new(Rails.root.join("spec/fixtures/files").to_s), at: "/test-clips" if Rails.env.test?`
   Markets in these scenarios use `video_url: "/test-clips/clip.mp4"`.
4. **Scenarios.** Add `features/feed/clip_player.feature` (new, tagged `@javascript`) with steps in `features/step_definitions/browser_steps.rb` (new):
   - **The clip freezes right before the action.** With the freeze point at 1.0 s, wait for `article.clip-card.is-frozen`. Then `evaluate_script("document.querySelector('article.clip-card video').currentTime")` should be within 0.15 of 1.0.
   - **Betting closes on screen when the countdown hits zero.** Sign in, set the market to lock in 6 seconds, and open the feed. The "Betting closed" button should then be disabled; check with `wait: 10`. This needs a new step, `"{string} locks in {int} second(s)"`, using `update_columns` like the existing minutes step.
   - **A stake chip fills the stake and estimates my payout.** alice stakes 60 on "Lands it" and bob 40 on "Bails". Pick "Bails" and tap 50. Stake should show 50 and the estimate "If you're right: about 79 credits back (×1.58)."
   - **Placing a bet updates the card without a page load.** Set `window.tolchuMarker` via `execute_script`, then predict. Expect "You picked Bails for 25 credits", a balance of 975, and the marker still set.

Gotchas
- **Don't use `When N minutes pass` in `@javascript` scenarios.** That step calls `travel`, which moves Ruby's clock but not the browser's. Set `locks_at` a few seconds ahead instead.
- **H.264 support varies.** Chromium and Chrome for Testing builds can lack H.264. If the clip never plays locally, use Google Chrome or switch the fixture to VP9/WebM.

## Acceptance criteria
- [ ] Cucumber: the four `@javascript` scenarios above pass locally and in the CI `test` job, with no workflow change
- [ ] Existing rack_test scenarios still run without a browser
- [ ] README "Testing" notes that `@javascript` scenarios need Chrome
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. This issue unblocks the browser scenarios in #7 and #8.
- **Out of scope:** Safari/Firefox runs, visual regression, device emulation
- **Size:** M
