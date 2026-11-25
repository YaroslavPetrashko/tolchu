require "rails_helper"
require "rake"

RSpec.describe "markets:lock_expired" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("markets:lock_expired") }

  def run_task
    Rake::Task["markets:lock_expired"].reenable
    Rake::Task["markets:lock_expired"].invoke
  end

  it "locks every market past its betting window and leaves open ones alone" do
    expired = create_list(:market, 2, :expired)
    still_open = create(:market)

    expect { run_task }.to output("Locked 2 expired markets.\nSettled 0 sealed markets.\n").to_stdout

    expect(expired.map { |market| market.reload.status }).to all(eq("locked"))
    expect(expired.first.locked_at).to eq(expired.first.locks_at)
    expect(still_open.reload).to be_open
  end

  it "settles an expired market on its sealed answer and pays the winner" do
    sealed = create(:market, sealed_answer_label: "Bails")
    winner = create(:user)
    place_bet(user: winner, market: sealed, outcome: "Bails", stake: 50)
    place_bet(user: create(:user), market: sealed, outcome: "Lands it", stake: 50)
    sealed.update_columns(locks_at: 1.minute.ago)

    expect { run_task }.to output("Locked 1 expired market.\nSettled 1 sealed market.\n").to_stdout

    expect(sealed.reload).to be_resolved
    expect(sealed.winning_outcome.label).to eq("Bails")
    expect(winner.reload.balance).to be > User::STARTING_CREDITS
  end

  it "reports zero when nothing is due and can be run again safely" do
    create(:market)

    2.times { expect { run_task }.to output("Locked 0 expired markets.\nSettled 0 sealed markets.\n").to_stdout }
  end
end
