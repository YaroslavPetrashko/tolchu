require "rails_helper"
require "rake"

RSpec.describe Markets::LockExpired do
  it "locks open markets past their deadline and leaves the rest alone" do
    expired = create(:market, :expired)
    still_open = create(:market, locks_at: 10.minutes.from_now)
    already_locked = create(:market, :locked)

    result = described_class.call

    expect(result.value).to eq(1)
    expect(expired.reload).to have_attributes(status: "locked", locked_at: expired.locks_at)
    expect(still_open.reload).to be_open
    expect(already_locked.reload).to be_locked
  end
end

RSpec.describe "markets:lock_expired rake task" do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.empty? }

  it "locks expired markets and reports how many" do
    create(:market, :expired)

    expect { Rake::Task["markets:lock_expired"].execute }.to output("Locked 1 expired market.\n").to_stdout
  end
end
