require "rails_helper"

RSpec.describe "Markets" do
  let(:creator) { create(:user, username: "StuntLab") }
  let!(:market) { create(:market, creator:, question: "Will he land the kickflip?", outcome_labels: [ "Lands it", "Bails" ]) }

  describe "GET / (the feed)" do
    it "shows open markets with their outcomes and pool to guests" do
      place_bet(user: create(:user), market:, outcome: "Lands it", stake: 60)
      place_bet(user: create(:user), market:, outcome: "Bails", stake: 40)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Will he land the kickflip?", "@StuntLab asks", "Lands it", "Bails")
      expect(response.body).to include("100 credits</strong> in the pool", "2 predictions", "60%", "40%")
      expect(response.body).to include("Sign in to predict")
      expect(response.body).not_to include("Place bet")
    end

    it "shows a bet form to signed-in fans" do
      sign_in_as create(:user)
      get root_path

      expect(response.body).to include("Place bet", %(name="outcome_id"), %(name="stake"), %(value="feed"))
    end

    it "lays the outcomes out on the bet pad with the default stake and what it would win" do
      place_bet(user: create(:user), market:, outcome: "Lands it", stake: 60)
      place_bet(user: create(:user), market:, outcome: "Bails", stake: 40)
      sign_in_as create(:user)

      get root_path

      expect(response.body).to include("bet-pad--2", "bet-pad__section--l", "bet-pad__section--r", %(data-controller="bet-pad"))
      expect(response.body).to include(%(value="#{Bet::DEFAULT_STAKE}"), "wins 15")
    end

    it "keeps score of this session's bets above the feed" do
      fan = create(:user)
      sign_in_as fan
      place_bet(user: fan, market:, outcome: "Bails", stake: 20)

      get root_path

      expect(response.body).to include(%(id="session-strip"), "session-tile--pending", "Will he land the kickflip?: Pending")
      expect(response.body).to include(%(href="/?focus=#{market.id}"))
    end

    it "brings a tapped session tile's clip to the top of the feed and marks its tile" do
      fan = create(:user)
      sign_in_as fan
      place_bet(user: fan, market:, outcome: "Bails", stake: 20)
      newer = create(:market, question: "Closes first?", locks_at: 2.minutes.from_now)

      get root_path(focus: market.id)

      expect(response.body.index(market.question)).to be < response.body.index(newer.question)
      expect(response.body).to include(%(aria-current="true"))
    end

    it "lets a fan reopen the pad to change a pending bet" do
      fan = create(:user)
      place_bet(user: fan, market:, outcome: "Bails", stake: 20)
      sign_in_as fan

      get root_path

      expect(response.body).to include("bet-pill__edit", %(data-controller="bet-edit"), "Change bet", %(name="_method" value="patch"))
    end

    it "offers guests a sign-in link where the session score would be" do
      get root_path

      expect(response.body).to include(%(id="session-strip"), %(class="session-bar__net" href="/session/new">Sign in</a>))
    end

    it "tucks balance and navigation into a pull-up menu" do
      sign_in_as create(:user, balance: 1_000)
      get root_path

      expect(response.body).to include("account-sheet__handle")
      expect(Nokogiri::HTML5.fragment(response.body).at_css("#wallet-balance").text).to eq("1,000")
      expect(response.body).to include(%(href="/wallet"), %(href="/studio/markets"), %(href="/how-it-works"), "Sign out")
    end

    it "offers guests sign in, sign up and the explainer in the menu" do
      get root_path

      expect(response.body).to include("account-sheet__panel", %(href="/registration/new"), %(href="/how-it-works"))
    end

    it "drains a ring around the bet button as the lock approaches" do
      sign_in_as create(:user)
      get root_path

      expect(response.body).to include("bet-pad__ring", %(pathLength="100"), %(data-countdown-target="ring"))
    end

    it "shows the feed without a nav bar" do
      get root_path

      expect(response.body).not_to include(%(class="topbar"))
    end

    it "turns the card into a pending review screen once the fan has bet" do
      fan = create(:user)
      place_bet(user: fan, market:, outcome: "Bails", stake: 20)
      sign_in_as fan

      get root_path

      expect(response.body).to include("clip-card--review clip-card--pending", "bet-pad--review", "bet-pill bet-pill--pending")
    end

    it "shows the fan's existing prediction instead of the form" do
      fan = create(:user)
      place_bet(user: fan, market:, outcome: "Bails", stake: 20)
      sign_in_as fan

      get root_path

      expect(response.body).to include(%(title="Bails">Bails</button>), %(20<span class="visually-hidden"> credits</span>))
      expect(response.body).not_to include("Place bet")
    end

    it "tells creators they can't bet on their own market" do
      sign_in_as creator
      get root_path

      expect(response.body).to match(/bet-pad__button--static">\s*Yours\s*</)
    end

    it "shows locked and settled markets with their state" do
      Markets::Lock.call(market:)
      settled = create(:market, question: "Penalty: left or right?", outcome_labels: %w[Left Right])
      Markets::Lock.call(market: settled)
      Markets::Resolve.call(market: settled, winning_outcome_id: settled.outcomes.first.id)

      get root_path

      expect(response.body).to include("clip-card--locked", "clip-card--resolved", "outcome--winner")
      expect(response.body).not_to include("badge--")
    end

    it "invites people to post when the feed is empty" do
      Markets::Cancel.call(market:)
      get root_path

      expect(response.body).to include("No clips yet")
    end
  end

  describe "sealed markets" do
    let!(:sealed) { create(:market, question: "Sealed?", sealed_answer_label: "Bails") }
    let(:fan) { create(:user) }

    before do
      sign_in_as fan
      place_bet(user: fan, market: sealed, outcome: "Bails", stake: 20)
      place_bet(user: create(:user), market: sealed, outcome: "Lands it", stake: 20)
    end

    it "shows the result as soon as betting locks, with no locked-and-waiting state" do
      travel_to(sealed.locks_at + 1.second) { get root_path }

      expect(sealed.reload).to be_resolved
      expect(response.body).to include("clip-card--review clip-card--won")
    end

    it "redraws a single card and the session bar when its countdown runs out" do
      travel_to(sealed.locks_at + 1.second) { get card_market_path(sealed, context: "feed") }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(<turbo-stream action="replace" target="market_#{sealed.id}">), "clip-card--won")
      expect(response.body).to include(%(<turbo-stream action="replace" target="session-strip">), "session-tile--won")
    end

    it "redraws the card for a guest without a session bar, since guests have no session" do
      delete session_path
      travel_to(sealed.locks_at + 1.second) { get card_market_path(sealed, context: "feed") }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<turbo-stream action="replace" target="market_#{sealed.id}">), "clip-card--resolved")
      expect(response.body).not_to include("session-strip", "clip-card--review")
    end

    it "keeps bets returning to the clip page when the card is redrawn there" do
      open_market = create(:market, question: "Still open?")

      get card_market_path(open_market, context: "page")
      expect(response.body).to include(%(name="context" value="page"))

      get card_market_path(open_market, context: "anything-else")
      expect(response.body).to include(%(name="context" value="feed"))
    end
  end

  describe "the session bar" do
    let(:fan) { create(:user) }

    it "shows at most four segments, with arrows only once there are more" do
      sign_in_as fan
      markets = create_list(:market, 5)
      markets.first(4).each { |market| place_bet(user: fan, market:, outcome: "Lands it", stake: 5) }

      get root_path
      expect(response.body.scan("session-tile--pending").size).to eq(4)
      expect(response.body).not_to include("session-bar__arrow")

      place_bet(user: fan, market: markets.last, outcome: "Lands it", stake: 5)
      get root_path
      expect(response.body.scan(/data-session-bar-target="segment" hidden/).size).to eq(1)
      expect(response.body.scan("session-bar__arrow").size).to eq(2)
    end
  end

  describe "GET /markets/:id" do
    it "shows the clip, the pool breakdown, and when betting closes" do
      get market_path(market)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Pool breakdown", "Will he land the kickflip?", "Betting closes")
      expect(response.body).to include(%(value="page")).or include("Sign in to predict")
    end

    it "shows the settlement once resolved" do
      place_bet(user: create(:user), market:, outcome: "Lands it", stake: 100)
      place_bet(user: create(:user), market:, outcome: "Bails", stake: 100)
      Markets::Lock.call(market:)
      Markets::Resolve.call(market:, winning_outcome_id: outcome(market, "Lands it").id)

      get market_path(market)

      expect(response.body).to include("Settlement", "House fee", "Creator reward", "100%")
    end

    it "explains a cancelled market" do
      Markets::Cancel.call(market:)
      get market_path(market)

      expect(response.body).to include("clip-card--cancelled")
      expect(response.body).to match(/bet-pad__button--static">\s*Void\s*</)
    end

    it "returns 404 for an unknown market" do
      get market_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end
end
