require "rails_helper"

RSpec.describe "Studio markets" do
  let(:creator) { create(:user, username: "StuntLab", balance: 0) }
  let(:market_params) do
    {
      market: {
        question: "Will she stick the landing?",
        video_url: "https://cdn.example.com/flip.mp4",
        freeze_at: "4.5",
        betting_window_minutes: "15",
        description: "Backflip off the ledge",
        outcomes_attributes: { "0" => { label: "Sticks it" }, "1" => { label: "Wipes out" }, "2" => { label: "" }, "3" => { label: "" } }
      }
    }
  end

  it "requires a signed-in user" do
    get studio_markets_path
    expect(response).to redirect_to(new_session_path)
  end

  it "redirects /studio to the dashboard" do
    get "/studio"
    expect(response).to redirect_to("/studio/markets")
  end

  context "when signed in" do
    before { sign_in_as creator }

    describe "GET /studio/markets" do
      it "lists only the creator's own markets" do
        create(:market, creator:, question: "My market?")
        create(:market, question: "Someone else's market?")

        get studio_markets_path

        expect(response.body).to include("My market?")
        expect(response.body).not_to include("Someone else&#39;s market?")
      end

      it "offers the right actions for each phase" do
        open_market = create(:market, creator:, question: "Open one?")
        locked_market = create(:market, :locked, creator:, question: "Locked one?")

        get studio_markets_path

        expect(response.body).to include(lock_studio_market_path(open_market), resolve_studio_market_path(locked_market))
        expect(response.body).to include("Lock betting now", "Declare result", "What happened?")
      end

      it "shows the settlement for resolved markets and a note for cancelled ones" do
        resolved = create(:market, creator:)
        place_bet(user: create(:user), market: resolved, outcome: "Lands it", stake: 100)
        place_bet(user: create(:user), market: resolved, outcome: "Bails", stake: 100)
        Markets::Lock.call(market: resolved)
        Markets::Resolve.call(market: resolved, winning_outcome_id: outcome(resolved, "Bails").id)
        Markets::Cancel.call(market: create(:market, creator:))

        get studio_markets_path

        expect(response.body).to include("Your reward", "5 credits", "Contest score", "Cancelled. Every stake was refunded.")
      end

      it "lists markets that need a result first, then live ones, then settled ones" do
        settled = create(:market, creator:, question: "Settled one?")
        Markets::Cancel.call(market: settled)
        create(:market, creator:, question: "Live one?")
        create(:market, :locked, creator:, question: "Needs a result?")

        get studio_markets_path

        positions = [ "Needs a result?", "Live one?", "Settled one?" ].map { |question| response.body.index(question) }
        expect(positions).to eq(positions.sort)
      end

      it "invites a first market when the creator has none" do
        get studio_markets_path
        expect(response.body).to include("Create your first market")
      end
    end

    describe "GET /studio/markets/new" do
      it "renders a form with four outcome slots" do
        get new_studio_market_path

        expect(response.body).to include("Publish market", "Outcome 1", "Outcome 4", "Betting window")
      end
    end

    describe "POST /studio/markets" do
      it "publishes the market with its outcomes" do
        freeze_time do
          expect { post studio_markets_path, params: market_params }.to change(Market, :count).by(1)

          market = creator.created_markets.sole
          expect(market).to have_attributes(question: "Will she stick the landing?", freeze_at: 4.5, locks_at: 15.minutes.from_now)
          expect(market.outcomes.map(&:label)).to eq([ "Sticks it", "Wipes out" ])
          expect(response).to redirect_to(studio_markets_path)
          expect(flash[:notice]).to eq("Your market is live! Betting closes 15 minutes from now.")
        end
      end

      it "re-renders the form with errors" do
        params = market_params.deep_merge(market: { video_url: "not a link", outcomes_attributes: { "1" => { label: "" } } })

        expect { post studio_markets_path, params: }.not_to change(Market, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Clip URL must be an http(s) link to a video file",
                                          "Outcomes must have between 2 and 4 options (you have 1)")
        expect(response.body.scan("market[outcomes_attributes]").size).to be >= 4
      end
    end

    describe "PATCH lock / resolve / cancel" do
      let(:market) { create(:market, creator:, question: "Will it land?") }

      before do
        place_bet(user: create(:user, username: "alice"), market:, outcome: "Lands it", stake: 100)
        place_bet(user: create(:user, username: "bob"), market:, outcome: "Bails", stake: 100)
      end

      it "locks betting" do
        patch lock_studio_market_path(market)

        expect(response).to redirect_to(studio_markets_path)
        expect(response).to have_http_status(:see_other)
        expect(flash[:notice]).to eq("Betting is locked on “Will it land?”. Declare the result once the play is over.")
        expect(market.reload).to be_locked
      end

      it "reports when locking isn't possible" do
        patch lock_studio_market_path(market)
        patch lock_studio_market_path(market)

        expect(flash[:alert]).to eq("Betting has already closed on this market")
      end

      it "declares the result and pays out" do
        patch lock_studio_market_path(market)
        patch resolve_studio_market_path(market), params: { winning_outcome_id: outcome(market, "Lands it").id }

        expect(flash[:notice]).to eq("Result declared: Lands it. Payouts sent!")
        expect(User.find_by!(username: "alice").balance).to eq(1_090)
        expect(creator.reload.balance).to eq(5)
      end

      it "refuses to declare a result while betting is open" do
        patch resolve_studio_market_path(market), params: { winning_outcome_id: outcome(market, "Lands it").id }

        expect(flash[:alert]).to eq("Betting is still open. Lock the market before declaring the result")
        expect(market.reload).to be_open
      end

      it "cancels and refunds" do
        patch cancel_studio_market_path(market)

        expect(flash[:notice]).to eq("“Will it land?” was cancelled and every stake was refunded.")
        expect(User.find_by!(username: "bob").balance).to eq(1_000)
      end

      it "can't manage another creator's market" do
        rival_market = create(:market)

        patch lock_studio_market_path(rival_market)
        expect(response).to have_http_status(:not_found)
        patch cancel_studio_market_path(rival_market)
        expect(response).to have_http_status(:not_found)
        expect(rival_market.reload).to be_open
      end
    end
  end
end
