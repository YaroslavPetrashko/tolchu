class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Too many attempts. Try again in a few minutes." }

  def new
    redirect_to root_path if authenticated?
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url, notice: "Welcome back, #{user.username}!"
    else
      redirect_to new_session_path, alert: "That email and password don't match."
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: "You've been signed out.", status: :see_other
  end
end
