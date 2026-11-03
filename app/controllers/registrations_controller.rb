class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Too many sign-ups. Try again in a few minutes." }

  def new
    return redirect_to root_path if authenticated?

    @user = User.new
  end

  def create
    @user = User.register(registration_params)
    if @user.persisted?
      start_new_session_for @user
      redirect_to after_authentication_url,
                  notice: "Welcome to Tolchu, #{@user.username}! You have #{User::STARTING_CREDITS.to_fs(:delimited)} free credits to play with."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def registration_params
      params.expect(user: %i[ username email_address password password_confirmation ])
    end
end
