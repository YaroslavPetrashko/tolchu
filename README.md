# Tolchu: know what happens next? Bet on it.

Tolchu embeds **parimutuel micro-betting** in a feed of short video clips. Each clip freezes right before the
action ("Will the free throw go in?"). You pick one of 2–4 outcomes with a single tap, betting locks before the
play, and the result plays out on screen seconds later. All stakes go into one shared pool. Correct predictions
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
| `courtvision@tolchu.app` | Creator of the basketball clips, with one market waiting for a result |

1. **Sign up** (or use `fan@tolchu.app`). New accounts get 1,000 credits.
2. **Scroll the feed.** Each clip plays up to its freeze frame and asks *what happens next?* The bars show how the
   pool is split. `×1.86` is what each credit pays if that outcome wins.
3. **Place a bet:** pick an outcome, tap a stake chip (max 100 per market), and press **Place bet**.
   The card, pool, and your balance update in place.
4. **Settle a market:** sign in as `courtvision@tolchu.app`, open **Studio**, and declare the result of
   *"Does #67 finish at the rim?"* (betting is already locked). Payouts land immediately. Check a bettor's
   **Wallet** to see the ledger. You can also **Lock betting now** on any live market, then declare its result.
5. **Post your own market** from **Studio → New market** with any direct `.mp4` link, a freeze point in seconds,
   and 2–4 outcomes.

## Features in this iteration

- Accounts: sign up (1,000 starting credits), sign in/out, protected pages
- Clip feed: live markets closing soonest first, then markets awaiting a result, then recent results. Each clip
  freezes before the action and reveals the ending once settled. Live countdown and projected payouts.
- Betting: one prediction per market, 1–100 credit stake cap, atomic wallet debit, hard server-side lock
  (bets are refused the instant a market locks, even from a stale page), creators can't bet on their own clips
- Parimutuel settlement: 5% rake (capped at the losing side so winners never lose money), pro-rata payouts
  rounded down, full refunds with no fee when there's no contest, creator reward of up to 50% of the rake
  scaled by the pool's *contest score*
- Creator studio: post a market, lock betting early, declare the result, cancel and refund
- Wallet: balance, pending/won/lost/refunded predictions, and an append-only ledger of every credit movement
- How-it-works explainer for first-time bettors

## Running locally

**Prerequisites:** Ruby 3.4.5 (see `.ruby-version`), PostgreSQL 14+ running locally, Bundler.

```sh
git clone git@github.com:YaroslavPetrashko/tolchu.git
cd tolchu
bin/setup --skip-server   # installs gems, creates the databases, and loads the demo data (db/seeds.rb)
bin/dev                   # http://localhost:3000
```

`bin/rails db:seed` reloads the demo data into an empty database (it skips itself if the demo users exist).

On macOS, if `bundle install` fails to link native gems with `unknown architecture arm64e.x1-macos`, point
the compiler at the 26.x SDK: `export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk`.

## Testing

```sh
bundle exec cucumber     # user stories (features/), 49 scenarios
bundle exec rspec        # unit + request specs (spec/), 215 examples
open coverage/index.html # merged coverage from both suites
bin/ci                   # everything CI runs: RuboCop, Brakeman, bundler-audit, importmap audit, RSpec, Cucumber
```

Coverage at the time of this submission: **99.4% of lines and 91.8% of branches** (RSpec and Cucumber combined).

### User stories (Cucumber)

| Feature file | Story |
|---|---|
| `features/accounts/sign_up.feature` | Sign up and get 1,000 starting credits, with validation for duplicates and weak passwords |
| `features/accounts/sign_in.feature` | Sign in/out, wrong password, protected pages redirect and return |
| `features/feed/browse_feed.feature` | Scroll clips with question, outcomes, and pool split. Ordering, locked and settled states, guests |
| `features/betting/place_bet.feature` | One-tap prediction, stake cap, insufficient credits, one bet per market, hard lock, no self-betting |
| `features/betting/payouts.feature` | Pro-rata payouts, fee cap, no-contest refunds, creator reward scaled by contest score |
| `features/studio/create_market.feature` | Creators post a clip market, with validation |
| `features/studio/settle_market.feature` | Lock before the play, declare the result, auto-lock, cancel and refund, only manage your own markets |
| `features/wallet/track_predictions.feature` | Pending and settled predictions, a ledger entry for every credit movement |
| `features/learn/how_it_works.feature` | Plain-English explainer of the parimutuel model |

## How it's built

Rails 8.1 · Ruby 3.4 · PostgreSQL · Hotwire (Turbo + Stimulus) · Propshaft and import maps, with no Node build step.

| Piece | Where |
|---|---|
| Parimutuel math (pure Ruby, exhaustively tested) | `app/models/parimutuel.rb`, `app/models/parimutuel/settlement.rb` |
| Every credit movement (row lock + ledger entry) | `app/models/wallet.rb`, `app/models/ledger_entry.rb` |
| Placing a bet atomically | `app/services/betting/place_bet.rb` |
| Market lifecycle: lock, resolve, cancel | `app/services/markets/` |
| Feed ordering | `app/models/market_feed.rb` |
| Clip freeze/reveal, countdown, stake estimate | `app/javascript/controllers/` |

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
