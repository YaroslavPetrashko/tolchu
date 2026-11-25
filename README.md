# Tolchu: know what happens next? Bet on it.

Tolchu embeds **parimutuel micro-betting** in a feed of short video clips. Each clip freezes right before the
action ("Will the free throw go in?"). You flick one button toward one of 2–4 outcomes, betting locks before the
play, and the card turns green or red the moment it does. All stakes go into one shared pool. Correct predictions
split it in proportion to their stakes, minus a flat 5% house fee, so **the house never bets against you**.
Creators turn their own clips into markets and earn a share of the fee that grows with how contested the pool is.

> Tolchu uses free play-money credits. Every account starts with 1,000.

| | |
|---|---|
| **Live app (Heroku)** | https://tolchu-24414638a003.herokuapp.com |
| **Code (GitHub)** | https://github.com/YaroslavPetrashko/tolchu |

## Team

| Name | UNI |
|---|---|
| Yaroslav Petrashko | yp2849 |
| Bailey Kornegay | bk2909 |
| Sherniyaz Bolat | sb5389 |
| Jack Bhalla | jsb2302 |

## Try it in two minutes

Demo accounts (password for all: `password123`):

| Email | Role |
|---|---|
| `fan@tolchu.app` | Bettor with one pending, one won, and one lost prediction |
| `stuntlab@tolchu.app` | Creator of the stunt clips (backflip, board flip, pool jump, keepy-uppy, horse jump) |
| `courtvision@tolchu.app` | Creator of the basketball clips, with one older market waiting for a hand-declared result |

1. **Sign up** (or use `fan@tolchu.app`). New accounts get 1,000 credits.
2. **Scroll the feed.** Each clip plays up to its freeze frame with its question at the top. Under it, the bet pad
   shows each outcome with `×1.86` (what each credit pays if it wins), its share of the pool, and what your current
   stake would win. The ring around the round button drains as the lock approaches.
3. **Place a bet:** flick the round button toward an outcome. Tap it to change the stake by 1, or hold it to ramp
   (the **− / +** toggle below picks the direction; the button turns red in −). Max 100 per market.
   On a keyboard, Tab to an outcome, use the arrow keys on the button for the stake, and press Enter.
4. **Watch it settle.** The card shows a countdown and a pill with your pick, stake and multiplier. Tap the pencil
   to change your bet before the lock. When the countdown hits zero the card turns green or red with your result,
   and a segment appears in the session bar at the top (tap one to jump back to that clip).
5. **Everything else** is in the menu behind the small grey handle at the bottom of the screen: balance, Wallet,
   Post a clip, Studio, How it works, Sign out.
6. **Post your own market** from **Studio → New market** with any direct `.mp4` link, a freeze point in seconds,
   2–4 outcomes, and the outcome that actually happens. That answer is sealed and settles the market the moment
   betting locks. Older markets without a sealed answer (like *"Does #67 finish at the rim?"*) are settled by hand
   from Studio.

## Features in this iteration

- Accounts: sign up (1,000 starting credits), sign in/out, protected pages
- Clip feed: one card per screen, live markets closing soonest first, then markets awaiting a result, then recent
  results. Each clip freezes before the action and reveals the ending once settled.
- Bet pad: flick to bet, tap or hold to set the stake, live multipliers and payout estimates, a draining lock ring,
  and review screens framed green, red or yellow with a pill showing your pick, stake and multiplier
- Betting: one prediction per market (changeable until the lock), 1–100 credit stake cap, atomic wallet debit,
  hard server-side lock (bets are refused the instant a market locks, even from a stale page), creators can't bet
  on their own clips
- Sealed results: creators seal the real answer when posting, and the market settles itself at the lock
- Session bar: one segment per bet since sign-in (four at a time, with looping arrows), the session's net result,
  and a small spark burst when it goes up
- Pull-up menu on every page in place of a nav bar
- Parimutuel settlement: 5% rake (capped at the losing side so winners never lose money), pro-rata payouts
  rounded down, full refunds with no fee when there's no contest, creator reward of up to 50% of the rake
  scaled by the pool's *contest score*
- Creator studio: post a market with a sealed answer, lock betting early, declare results for older markets,
  cancel and refund
- Wallet: balance, pending/won/lost/refunded predictions, and an append-only ledger of every credit movement
- How-it-works explainer for first-time bettors

## Running locally

**Prerequisites:** Ruby 3.4.13 (see `.ruby-version`; `rbenv install 3.4.13`), PostgreSQL 14+, Bundler.

No local Postgres? Run it in Docker and point Rails at it:

```sh
docker run -d --name tolchu-pg -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:16
export PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres   # fish: set -Ux PGHOST localhost (and so on)
```

Add `--pids-limit -1` to `docker run` if the container exits with `fork: Resource temporarily unavailable`
(rootless Podman). After a reboot, `docker start tolchu-pg`.

```sh
git clone git@github.com:YaroslavPetrashko/tolchu.git
cd tolchu
bin/setup --skip-server   # installs gems, creates the databases, and loads the demo data (db/seeds.rb)
bin/dev                   # http://localhost:3000
```

The demo's live markets lock 10–30 minutes after seeding and settle themselves on their sealed answers.
`bin/rails db:reset` reloads fresh demo data (stop `bin/dev` first). Run it after pulling a new migration too.

To try the gestures, use Chrome's device mode (Ctrl+Shift+M) or a phone on the same Wi-Fi:
`bin/rails server -b 0.0.0.0`, then open `http://<your-laptop-ip>:3000`.

On macOS, if `bundle install` fails to link native gems with `unknown architecture arm64e.x1-macos`, point
the compiler at the 26.x SDK: `export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk`.

## Testing

RSpec and Cucumber default to `RAILS_ENV=test`; their helpers reject other values before loading Rails. Use a dedicated test database connection, separate from development and production.

```sh
bundle exec cucumber     # user stories (features/), 49 scenarios
bundle exec rspec        # unit + request specs (spec/), 255 examples
open coverage/index.html # merged coverage from both suites
bin/ci                   # everything CI runs: RuboCop, Brakeman, bundler-audit, importmap audit, RSpec, Cucumber
```

CI fails when merged line coverage drops below 90%. `bin/coverage-check` runs the same check locally after both
suites; set `MIN_LINE_COVERAGE` to try another threshold.

Coverage: **97.8% of lines and 90.2% of branches** (RSpec and Cucumber combined).

### User stories (Cucumber)

| Feature file | Story |
|---|---|
| `features/accounts/sign_up.feature` | Sign up and get 1,000 starting credits, with validation for duplicates and weak passwords |
| `features/accounts/sign_in.feature` | Sign in/out, wrong password, protected pages redirect and return |
| `features/feed/clip_player.feature` | In a real browser: the clip freezes before the action, betting closes at zero, the stake estimate updates, flick and keyboard bets land in place |
| `features/feed/browse_feed.feature` | Scroll clips with question, outcomes, and pool split. Ordering, locked and settled states, guests |
| `features/betting/place_bet.feature` | Placing a prediction, stake cap, insufficient credits, one bet per market, hard lock, no self-betting |
| `features/betting/payouts.feature` | Pro-rata payouts, fee cap, no-contest refunds, creator reward scaled by contest score |
| `features/studio/create_market.feature` | Creators post a clip market with a sealed answer, with validation |
| `features/studio/settle_market.feature` | Lock before the play, declare the result, auto-lock, cancel and refund, only manage your own markets |
| `features/wallet/track_predictions.feature` | Pending and settled predictions, a ledger entry for every credit movement |
| `features/learn/how_it_works.feature` | Plain-English explainer of the parimutuel model |

## How it's built

Rails 8.1 · Ruby 3.4 · PostgreSQL · Hotwire (Turbo + Stimulus) · Propshaft and import maps, with no Node build step.

| Piece | Where |
|---|---|
| Parimutuel math (pure Ruby, exhaustively tested) | `app/models/parimutuel.rb`, `app/models/parimutuel/settlement.rb` |
| Every credit movement (row lock + ledger entry) | `app/models/wallet.rb`, `app/models/ledger_entry.rb` |
| Placing and changing a bet atomically | `app/services/betting/place_bet.rb`, `app/services/betting/change_bet.rb` |
| Market lifecycle: lock, resolve, settle sealed answers, cancel | `app/services/markets/` |
| Feed ordering and the session bar | `app/models/market_feed.rb`, `app/models/session_strip.rb` |
| Bet pad, card and menu views | `app/views/markets/`, `app/views/layouts/_account_sheet.html.erb` |
| Flick-to-bet, countdown ring, session bar, sparks, menu | `app/javascript/controllers/` |

**Invariants the tests enforce:** every user's `balance` equals the sum of their ledger entries; credits are
never created or destroyed by settlement (payouts + creator reward + house take = pool); a winner never gets
back less than their stake; a market settles at most once.

## Deployment (Heroku)

The app runs on Heroku (`heroku-24`, Ruby buildpack) with Heroku Postgres (`essential-0`).
Migrations run automatically in the release phase (`Procfile`). `app.json` describes the app for review apps.

```sh
heroku git:remote -a tolchu
git push heroku main
heroku run bin/rails db:seed      # first deploy only
heroku open
```

`GET /up` is the health check.

## Contributing

We work issue by issue, with one branch and one PR each, and every PR needs one approving review. Labels encode the
type of work, the area of the product, and the urgency against course deadlines.
See [CONTRIBUTING.md](CONTRIBUTING.md).

The planned work after this iteration (38 issues: real-time odds, clip uploads, sealed results, leaderboards,
review apps, Lighthouse CI, and more) is drafted in [`.github/backlog/`](.github/backlog/) and published to
GitHub Issues with `bin/github-backlog`.

## Credits

Demo clips are free stock footage from [Mixkit](https://mixkit.co/license/#videoFree), streamed from their CDN.
