require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  it "identifies the signed-in user from the session cookie" do
    user = create(:user)
    cookies.signed[:session_id] = user.sessions.create!.id

    connect "/cable"

    expect(connection.current_user).to eq(user)
  end

  it "rejects a visitor with no session cookie" do
    expect { connect "/cable" }.to have_rejected_connection
  end

  it "rejects a cookie that points at a session that was signed out" do
    session = create(:user).sessions.create!
    cookies.signed[:session_id] = session.id
    session.destroy

    expect { connect "/cable" }.to have_rejected_connection
  end
end
