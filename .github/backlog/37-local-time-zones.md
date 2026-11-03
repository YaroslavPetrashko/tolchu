---
title: "Show times in each viewer's own time zone"
labels: ["type: feature", "area: frontend", "priority: P3 · backlog"]
---
## Summary
As a viewer outside New York I want betting deadlines and wallet timestamps in my own time zone, so "Betting closes November 3, 2026 at 2:00 PM EST" doesn't make me do math. Real-user testing will include people in other zones.

## Context
- [`config/application.rb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/application.rb) sets `config.time_zone = "Eastern Time (US & Canada)"`; [`config/locales/en.yml`](https://github.com/YaroslavPetrashko/tolchu/blob/main/config/locales/en.yml) defines `short: "%b %-d, %-I:%M %p"` and `long: "%B %-d, %Y at %-I:%M %p %Z"`.
- Only two absolute times are rendered, both already inside `<time datetime>`:
  - [`markets/show.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/markets/show.html.erb): `<time datetime="<%= @market.locks_at.iso8601 %>"><%= l(@market.locks_at, format: :long) %></time>`
  - [`wallets/show.html.erb`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/views/wallets/show.html.erb): `<time datetime="<%= entry.created_at.iso8601 %>"><%= l(entry.created_at, format: :short) %></time>`
- Countdowns (`countdown_controller.js`, `lock_status_text`) and the studio's "closes … from now" flash are relative and need no change.

## Suggested implementation
1. A helper in [`ApplicationHelper`](https://github.com/YaroslavPetrashko/tolchu/blob/main/app/helpers/application_helper.rb), used by both views:
```ruby
# Eastern-time text is the no-JS fallback; local_time_controller rewrites it in the browser's zone.
def local_time_tag(time, format: :short)
  tag.time(l(time, format:), datetime: time.iso8601,
           data: { controller: "local-time", local_time_format_value: format })
end
```
2. `app/javascript/controllers/local_time_controller.js` (new):
```js
import { Controller } from "@hotwired/stimulus"

const FORMATS = {
  short: { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" },
  long: { year: "numeric", month: "long", day: "numeric", hour: "numeric", minute: "2-digit", timeZoneName: "short" }
}

export default class extends Controller {
  static values = { format: { type: String, default: "short" } }

  connect() {
    const date = new Date(this.element.dateTime)
    if (!Number.isNaN(date.getTime())) this.element.textContent = new Intl.DateTimeFormat("en-US", FORMATS[this.formatValue]).format(date)
  }
}
```
   Pass `"en-US"` so only the zone changes, not the language. Don't combine `dateStyle`/`timeStyle` with `timeZoneName`: `Intl.DateTimeFormat` throws a `TypeError`. Keep the zone name in the long format so viewers can tell the time is local.
3. Alternative: Basecamp's `local_time`, pinned with `bin/importmap pin local-time` and started with `LocalTime.start()` in `application.js`. It adds a dependency; choose it only if we want relative phrasing such as "Yesterday at 3:00 PM".
4. Keep `config.time_zone` as is: it stays the server-side fallback and the zone for logs.

## Acceptance criteria
- [ ] With the browser in Pacific time, the market page shows the deadline in Pacific time with its zone name, and wallet activity shows Pacific times; with JS off, both show the Eastern fallback
- [ ] RSpec: `local_time_tag` in `spec/helpers/application_helper_spec.rb` (datetime attribute, controller data, fallback text); `spec/requests/markets_spec.rb` and `spec/requests/wallets_spec.rb` assert `time[datetime][data-controller="local-time"]`
- [ ] Cucumber: once #12 adds a JS driver, run the browser with `TZ=America/Los_Angeles` and check the deadline text
- [ ] `bin/ci` passes

## Notes
- **Depends on:** nothing. Browser tests need #12 (Browser-level Cucumber scenarios for the clip player, countdown, and stake estimate).
- **Out of scope:** a per-user time zone setting, other languages.
- **Size:** S
