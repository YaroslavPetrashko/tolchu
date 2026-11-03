---
title: "Let creators upload clips instead of pasting a URL"
labels: ["type: feature", "area: video", "area: creator-tools", "priority: P1 · iteration 2"]
milestone: "Iteration 2"
---
## Summary
As a creator, I want to upload a video file when I post a market. Most creators have nowhere to host an MP4, so asking them to paste a direct link stops them from posting at all.

## Context
- **Active Storage is off.** It was skipped when the app was generated: [`config/application.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/application.rb) has `# require "active_storage/engine"`, and there is no `config/storage.yml` and no `active_storage_*` tables.
- **The URL is the only clip source.** [`Market`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/models/market.rb) validates `video_url` (presence, at most 500 characters, `\A(https?://|/)\S+\z`). [`db/schema.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/db/schema.rb) has the column as `null: false`. [`spec/models/market_spec.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/spec/models/market_spec.rb) asserts `validate_presence_of(:video_url)`.
- **The form requires it.** [`studio/markets/new.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/studio/markets/new.html.erb) has a required "Clip URL" field, and [`Studio::MarketsController#market_params`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/controllers/studio/markets_controller.rb) permits `:video_url`.
- **Playback.** [`_market.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/_market.html.erb) renders `<video src="<%= market.video_url %>">`. `MarketFeed#base`, `MarketsController#show` and `BetsController#render_card_update` preload `:creator, :outcomes, :winning_outcome`.
- **Heroku limits.** The filesystem is ephemeral, and requests time out after 30 s.

## Suggested implementation
1. **Turn on Active Storage.** Uncomment the `require`, run `bin/rails active_storage:install`, and migrate. Add a migration with `change_column_null :markets, :video_url, true`. Add `/storage/*` to `.gitignore`.
2. **Configure storage.**
   - New `config/storage.yml` with three services: `test` (Disk, `tmp/storage`), `local` (Disk, `storage/`), and `amazon` (`service: S3`, reading `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET` from `ENV`).
   - Add `gem "aws-sdk-s3", require: false`, and set `config.active_storage.service` per environment.
   - Create a bucket in us-east-1 (the same AWS region as Heroku US) and an IAM user scoped to that bucket.
   - Set the four config vars on `tolchu` and in the pipeline's review-app config vars (#1).
   - Alternatives: Cloudflare R2 through the same S3 service (free tier, no egress fees), or Cloudinary's free tier.
3. **Bucket CORS.** Allow `PUT` from `https://tolchu-24414638a003.herokuapp.com`, `https://*.herokuapp.com` and `http://localhost:3000`, with headers `Content-Type`, `Content-MD5` and `Content-Disposition`. Without this, direct uploads fail in the browser.
4. **Direct uploads**, so 50 MB never streams through a dyno:
   - In `config/importmap.rb`: `pin "@rails/activestorage", to: "activestorage.esm.js"`.
   - In `application.js`: `import * as ActiveStorage from "@rails/activestorage"; ActiveStorage.start()`.
   - In the form: `form.file_field :clip, direct_upload: true, accept: "video/mp4,video/webm"`, labelled "Upload a clip". The URL field is no longer `required`. Permit `:clip`.
5. **Model.** Keep the `video_url` length and format rules, with `allow_blank: true`:

```ruby
has_one_attached :clip
CLIP_TYPES = %w[video/mp4 video/webm].freeze
validate :exactly_one_clip_source
validate :clip_is_a_small_video, if: -> { clip.attached? }

def exactly_one_clip_source
  return errors.add(:base, "Upload a clip or paste a clip URL") if video_url.blank? && !clip.attached?
  errors.add(:base, "Upload a clip or paste a clip URL, not both") if video_url.present? && clip.attached?
end

def clip_is_a_small_video
  errors.add(:clip, "must be an MP4 or WebM video") unless clip.blob.content_type.in?(CLIP_TYPES)
  errors.add(:clip, "must be 50 MB or smaller") if clip.blob.byte_size > 50.megabytes
end
```
6. **Playback helper.** Add `playback_url(market)` to [`ApplicationHelper`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/helpers/application_helper.rb): `market.clip.attached? ? rails_blob_path(market.clip) : market.video_url`.
   - The redirect hands out short-lived signed S3 URLs. Don't make the bucket public (see #27).
   - Use the helper in `_market.html.erb`, and add `.with_attached_clip` at the three preload sites.
7. **Test fixture.** `ffmpeg -f lavfi -i testsrc=duration=3:size=320x240:rate=30 -c:v libx264 -pix_fmt yuv420p -movflags +faststart spec/fixtures/files/clip.mp4`. It's shared with #12; whichever PR lands first adds it.

## Acceptance criteria
- [ ] On a review app, a creator uploads an MP4, and the clip plays and freezes in the feed
- [ ] The browser uploads straight to the bucket, and the form submit carries only the signed blob id
- [ ] Clear form errors for: no clip at all, both a file and a URL, a non-video file, a file over 50 MB. URL-only markets still work.
- [ ] RSpec `spec/models/market_spec.rb`: those four cases, using `file_fixture("clip.mp4")`, plus an updated `video_url` presence example
- [ ] RSpec `spec/requests/studio/markets_spec.rb`: a POST with `fixture_file_upload`
- [ ] RSpec `spec/helpers/application_helper_spec.rb`: `playback_url`
- [ ] Cucumber `features/studio/create_market.feature`: "Publishing a market with an uploaded clip" (`attach_file "Upload a clip"`)
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Uploads on review apps need #1's config vars.
- **Out of scope:** transcoding (including iPhone `.mov`/HEVC), posters/thumbnails, purging orphaned blobs from abandoned forms, hiding the ending before lock (#27 The full clip is downloadable before betting locks, which depends on this)
- **Size:** L
