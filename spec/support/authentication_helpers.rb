module AuthenticationHelpers
  # Signs in through the real sessions endpoint so request specs exercise the cookie flow.
  def sign_in_as(user, password: "password123")
    post session_path, params: { email_address: user.email_address, password: }
    expect(response).to redirect_to(root_url)
  end
end
