---
title: "The full clip is downloadable before betting locks, so the ending can be watched early"
labels: ["type: bug", "area: video", "area: betting-engine", "priority: P2 · final demo"]
milestone: "Final demo"
---
## Summary
Anyone can watch a clip's ending before betting locks, then bet with certainty. That breaks the how-it-works promise ("nobody gets to bet on something they've already seen"); uploaded clips must be protected before real users arrive for the final demo.

## Context
- [`markets/_market.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_market.html.erb) renders the whole clip as `<video src="<%= market.video_url %>">` in every phase.
- The freeze is client-side only ([`clip_controller.js`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/javascript/controllers/clip_controller.js) pauses at `freeze_at` until `revealed`); devtools, "Open video in new tab", or disabled JS play the ending.
- `video_url` is a pasted link ([`Market`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/market.rb) only checks it's http(s)), and the seeds hotlink Mixkit. Those can't be restricted; uploads from #9 can.

## Suggested implementation
Assumes #9 stores uploads with Active Storage on a private S3 bucket (Cloudinary: step 5).

1. **Cut a setup rendition.** `Clips::CutSetup` (new service, returns `ApplicationService::Result`) re-encodes 0 to `freeze_at`:
   `ffmpeg -v error -i full.mp4 -t <freeze_at> -c:v libx264 -preset veryfast -crf 23 -c:a aac -movflags +faststart setup.mp4`.
   Not `-c copy`: stream copy cuts on keyframes and can keep frames past the freeze point. Attach it as `has_one_attached :setup_clip`; run it in `Studio::MarketsController#create` before `@market.save` (short clips finish well inside Heroku's 30 s timeout) and re-render the form on failure. Wrap the shell call in `Clips::Ffmpeg` so specs can stub it.
2. **Keep both private.** S3 service with `public: false` (default), Block Public Access on. Blob keys are random, so the original is reachable only through a signed URL we issue.
3. **One gated URL.** Nest `resource :clip, only: :show` under `resources :markets`. `ClipsController#show` (new, `allow_unauthenticated_access`) picks the original only if `market.resolved?`, else `setup_clip`, then `expires_now` and `redirect_to blob.url(expires_in: 5.minutes), allow_other_host: true`. Uploaded clips render `market_clip_path(market, v: phase)` (the URL changes at resolution, so no cached redirect survives); pasted links keep `video_url`. Cards broadcast by #8 (Push locks and results to open feeds in real time) reuse the partial.
4. **Warn and deploy.** Under "Clip URL" in [`studio/markets/new.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/studio/markets/new.html.erb), say pasted links can be watched in full before betting locks. Add a static ffmpeg buildpack (e.g. `jonathanong/heroku-buildpack-ffmpeg-latest`) before `heroku/ruby` on the app and in [`app.json`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app.json); install `ffmpeg` in the `test` job of [`ci.yml`](https://github.com/YaroslavPetrashko/tolchu/blob/main/.github/workflows/ci.yml).
5. **If #9 chose Cloudinary:** a public upload plus an `eo_<freeze_at>` URL isn't enough, because deleting the `eo_…/` segment returns the original. Upload with `type: "authenticated"` and emit only signed URLs (the signature covers the transformation).

## Acceptance criteria
- [ ] While a market with an uploaded clip is open or locked, no URL in its HTML serves frames after `freeze_at`; the clip endpoint redirects to the setup
- [ ] The setup lasts ≤ `freeze_at` (`ffprobe`)
- [ ] After `Markets::Resolve` the endpoint redirects to the original and the card plays to the end; cancelled markets keep the setup
- [ ] Unsigned requests for either S3 object return 403
- [ ] The new-market form warns that pasted links can be watched in full
- [ ] RSpec: `spec/services/clips/cut_setup_spec.rb` (real ffmpeg, 2 s fixture), `spec/requests/clips_spec.rb` (target per phase), `spec/requests/markets_spec.rb` (no original URL before resolution)
- [ ] Cucumber: "Bettors only get the setup until the result is in" (card `src` is the clip endpoint)
- [ ] `bin/ci` passes

## Notes
- **Depends on:** #9 (Let creators upload clips instead of pasting a URL)
- **Related:** #39 (Edit or delete a market before anyone bets) must re-cut when the clip or `freeze_at` changes; #35 (Share a clip with rich link previews) must not expose the original in `og:video`.
- **Out of scope:** pasted links (including seeded Mixkit clips), screen recording, adaptive bitrate.
- **Size:** L
