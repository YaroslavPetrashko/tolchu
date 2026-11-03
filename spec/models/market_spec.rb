require "rails_helper"

RSpec.describe Market do
  describe "validations" do
    subject { build(:market) }

    it { is_expected.to belong_to(:creator).class_name("User") }
    it { is_expected.to belong_to(:winning_outcome).class_name("Outcome").optional }
    it { is_expected.to have_many(:outcomes).dependent(:destroy) }
    it { is_expected.to have_many(:bets) }
    it { is_expected.to validate_presence_of(:question) }
    it { is_expected.to validate_length_of(:question).is_at_most(140) }
    it { is_expected.to validate_length_of(:description).is_at_most(500) }
    it { is_expected.to validate_presence_of(:video_url) }
    it { is_expected.to validate_numericality_of(:freeze_at).is_greater_than_or_equal_to(0).is_less_than(600) }

    it "accepts http(s) links and root-relative paths for the clip" do
      expect(build(:market, video_url: "https://cdn.example.com/a.mp4")).to be_valid
      expect(build(:market, video_url: "/clips/a.mp4")).to be_valid
    end

    it "rejects clip links that aren't web URLs" do
      %w[javascript:alert(1) ftp://example.com/a.mp4 not-a-url].each do |url|
        market = build(:market, video_url: url)
        expect(market).not_to be_valid
        expect(market.errors.full_messages).to include("Clip URL must be an http(s) link to a video file")
      end
    end

    it "requires between two and four outcomes" do
      expect(build(:market, outcome_labels: [ "Only one" ])).not_to be_valid
      expect(build(:market, outcome_labels: %w[A B C D])).to be_valid
      too_many = build(:market, outcome_labels: %w[A B C D E])
      expect(too_many).not_to be_valid
      expect(too_many.errors.full_messages).to include("Outcomes must have between 2 and 4 options (you have 5)")
    end

    it "requires outcome labels to be different, ignoring case" do
      market = build(:market, outcome_labels: [ "Yes", "yes " ])
      expect(market).not_to be_valid
      expect(market.errors.full_messages).to include("Outcomes must all be different")
    end

    it "requires the betting deadline to be in the future when created" do
      market = build(:market, locks_at: 1.minute.ago)
      expect(market).not_to be_valid
      expect(market.errors.full_messages).to include("Betting deadline must be in the future")
    end

    it "only accepts the offered betting windows" do
      expect(build(:market, betting_window_minutes: 7)).not_to be_valid
    end

    it "only accepts known statuses" do
      expect(build(:market, status: "paused")).not_to be_valid
    end
  end

  describe "creating from the studio form" do
    let(:creator) { create(:user) }

    it "turns the betting window into a lock time" do
      freeze_time do
        market = creator.created_markets.create!(
          question: "Will it land?", video_url: "https://cdn.example.com/a.mp4", betting_window_minutes: 60,
          outcomes_attributes: [ { label: "Yes" }, { label: "No" } ]
        )
        expect(market.locks_at).to eq(1.hour.from_now)
      end
    end

    it "ignores blank outcome fields and numbers the rest in order" do
      market = creator.created_markets.create!(
        question: "Will it land?", video_url: "https://cdn.example.com/a.mp4", betting_window_minutes: 15,
        outcomes_attributes: [ { label: "Yes" }, { label: "" }, { label: "No" }, { label: " " } ]
      )
      expect(market.outcomes.map { |o| [ o.label, o.position ] }).to eq([ [ "Yes", 0 ], [ "No", 1 ] ])
    end
  end

  describe "lifecycle predicates" do
    let(:market) { create(:market, locks_at: 10.minutes.from_now) }

    it "accepts bets while open and before the deadline" do
      expect(market.accepting_bets?).to be(true)
      expect(market.awaiting_result?).to be(false)
      expect(market.phase).to eq(:open)
    end

    it "stops accepting bets the instant the deadline passes, even before the status is updated" do
      expect(market.accepting_bets?(market.locks_at - 0.001)).to be(true)
      expect(market.accepting_bets?(market.locks_at)).to be(false)

      travel_to(market.locks_at + 1.second) do
        expect(market).to be_open
        expect(market.accepting_bets?).to be(false)
        expect(market.awaiting_result?).to be(true)
        expect(market.phase).to eq(:locked)
      end
    end

    it "reports locked, resolved, and cancelled phases" do
      market.update_columns(status: "locked")
      expect(market.phase).to eq(:locked)
      market.update_columns(status: "resolved")
      expect(market.phase).to eq(:resolved)
      expect(market).to be_settled
      market.update_columns(status: "cancelled")
      expect(market.phase).to eq(:cancelled)
      expect(market.awaiting_result?).to be(false)
    end
  end

  describe "scopes" do
    let!(:open_market) { create(:market, locks_at: 5.minutes.from_now) }
    let!(:expired_market) { create(:market, :expired) }
    let!(:locked_market) { create(:market, :locked) }

    it ".accepting_bets returns open markets before their deadline" do
      expect(described_class.accepting_bets).to contain_exactly(open_market)
    end

    it ".awaiting_result returns locked markets and open markets past their deadline" do
      expect(described_class.awaiting_result).to contain_exactly(expired_market, locked_market)
    end
  end

  describe "pool helpers" do
    let(:market) { create(:market) }

    before do
      place_bet(user: create(:user), market:, outcome: "Lands it", stake: 75)
      place_bet(user: create(:user), market:, outcome: "Bails", stake: 25)
      market.reload
    end

    it "computes the contest score from the outcome pools" do
      expect(market.contest_score).to eq(Rational(1, 2))
    end

    it "projects the payout multiple for an outcome" do
      expect(market.projected_multiplier(outcome(market, "Bails"))).to eq(Rational(95, 25))
      expect(market.projected_multiplier(outcome(market, "Lands it"), stake: 25)).to eq(Rational(119, 100))
    end
  end
end
