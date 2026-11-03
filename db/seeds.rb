# Demo data for local development and the Heroku deployment.
#
#   bin/rails db:seed              # locally
#   heroku run bin/rails db:seed   # production
#
# Safe to re-run: it does nothing if the demo creators already exist.
# Everything goes through the real services (User.register, Betting::PlaceBet,
# Markets::Lock/Resolve), so balances, pools, and the ledger stay consistent.
#
# Clips are free stock footage from Mixkit (https://mixkit.co/license/#videoFree),
# streamed from their CDN. Correct answers are noted per clip so the demo
# creators can settle markets truthfully.

DEMO_PASSWORD = "password123".freeze

if User.exists?(username: "StuntLab")
  puts "Demo data already loaded. Skipping."
  return
end

def demo_user(username)
  User.register(username:, email_address: "#{username.downcase}@tolchu.app", password: DEMO_PASSWORD).tap do |user|
    raise "Could not create #{username}: #{user.errors.full_messages.to_sentence}" unless user.persisted?
  end
end

def clip(id)
  "https://assets.mixkit.co/videos/#{id}/#{id}-720.mp4"
end

def post_market(creator:, question:, clip_id:, freeze_at:, outcomes:, closes_in:, description: nil)
  creator.created_markets.create!(
    question:, description:, video_url: clip(clip_id), freeze_at:, locks_at: closes_in.from_now,
    outcomes_attributes: outcomes.map { |label| { label: } }
  )
end

def bet!(user, market, outcome, stake)
  result = Betting::PlaceBet.call(user:, market:, outcome_id: market.outcomes.find_by!(label: outcome).id, stake:)
  raise "Seed bet failed: #{result.error}" if result.failure?
end

def settle!(market, winner)
  Markets::Lock.call(market:)
  result = Markets::Resolve.call(market: market.reload, winning_outcome_id: market.outcomes.find_by!(label: winner).id)
  raise "Seed settlement failed: #{result.error}" if result.failure?
end

ActiveRecord::Base.transaction do
  stunt_lab = demo_user("StuntLab")
  court_vision = demo_user("CourtVision")
  fan = demo_user("fan")
  crowd = %w[alice bob carol dan erin frank grace].map { |name| demo_user(name) }
  alice, bob, carol, dan, erin, frank, grace = crowd

  # --- Live markets (open for betting) ------------------------------------

  # Answer: Buckets (the pull-up drops clean through the net).
  jumper = post_market(
    creator: court_vision, question: "Will #67's pull-up jumper drop?", clip_id: 44468, freeze_at: 3.1,
    outcomes: [ "Buckets", "Brick", "Blocked" ], closes_in: 21.days,
    description: "One-on-one, defender closing out hard."
  )
  bet!(alice, jumper, "Buckets", 60)
  bet!(bob, jumper, "Brick", 40)
  bet!(carol, jumper, "Blocked", 25)
  bet!(dan, jumper, "Buckets", 30)
  bet!(fan, jumper, "Brick", 20)

  # Answer: Sticks the landing.
  backflip = post_market(
    creator: stunt_lab, question: "Will he stick the standing backflip?", clip_id: 41010, freeze_at: 3.2,
    outcomes: [ "Sticks the landing", "Eats dirt" ], closes_in: 25.days,
    description: "No mat, no spotter, sandy ground."
  )
  bet!(erin, backflip, "Eats dirt", 50)
  bet!(frank, backflip, "Sticks the landing", 35)
  bet!(grace, backflip, "Eats dirt", 15)

  # Answer: Lands it.
  board_flip = post_market(
    creator: stunt_lab, question: "Does he land the board flip?", clip_id: 34382, freeze_at: 1.0,
    outcomes: [ "Lands it", "Bails" ], closes_in: 28.days
  )
  bet!(alice, board_flip, "Bails", 20)
  bet!(dan, board_flip, "Lands it", 45)

  # Answer: Balances it on his head.
  header = post_market(
    creator: stunt_lab, question: "Keepy-uppy: what happens to the ball?", clip_id: 2923, freeze_at: 8.0,
    outcomes: [ "Balances it on his head", "Drops it", "Keeps juggling" ], closes_in: 30.days
  )
  bet!(bob, header, "Drops it", 30)
  bet!(erin, header, "Keeps juggling", 20)

  # --- Waiting for a result (betting locked, creator still has to declare) --

  # Answer: Scores.
  drive = post_market(
    creator: court_vision, question: "Does #67 finish at the rim?", clip_id: 44465, freeze_at: 4.3,
    outcomes: [ "Scores", "Misses", "Gets blocked" ], closes_in: 1.hour
  )
  bet!(carol, drive, "Scores", 50)
  bet!(frank, drive, "Gets blocked", 40)
  bet!(grace, drive, "Misses", 10)
  Markets::Lock.call(market: drive)

  # --- Settled markets ------------------------------------------------------

  # Answer: Feet first.
  pool_jump = post_market(
    creator: stunt_lab, question: "Feet first or head first?", clip_id: 23078, freeze_at: 2.8,
    outcomes: [ "Feet first", "Head first", "Chickens out" ], closes_in: 1.hour
  )
  bet!(fan, pool_jump, "Feet first", 50)
  bet!(alice, pool_jump, "Head first", 40)
  bet!(bob, pool_jump, "Chickens out", 30)
  bet!(carol, pool_jump, "Feet first", 25)
  settle!(pool_jump, "Feet first")

  # Answer: Clears it clean.
  horse = post_market(
    creator: stunt_lab, question: "Clean round or knocked rail?", clip_id: 45835, freeze_at: 3.6,
    outcomes: [ "Clears it clean", "Knocks a rail", "Refuses the jump" ], closes_in: 1.hour
  )
  bet!(fan, horse, "Knocks a rail", 30)
  bet!(dan, horse, "Clears it clean", 60)
  bet!(erin, horse, "Refuses the jump", 10)
  settle!(horse, "Clears it clean")
end

puts "Seeded #{User.count} users and #{Market.count} markets."
puts "Demo logins (password: #{DEMO_PASSWORD}): fan@tolchu.app, stuntlab@tolchu.app, courtvision@tolchu.app"
