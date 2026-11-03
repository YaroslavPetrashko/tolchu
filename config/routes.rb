Rails.application.routes.draw do
  root "markets#index"

  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  get "sign_up", to: "registrations#new"
  get "sign_in", to: "sessions#new"

  resources :markets, only: %i[index show] do
    resources :bets, only: :create
  end
  resource :wallet, only: :show

  namespace :studio do
    resources :markets, only: %i[index new create] do
      member do
        patch :lock
        patch :resolve
        patch :cancel
      end
    end
  end
  get "studio", to: redirect("/studio/markets")

  get "how-it-works", to: "pages#how_it_works", as: :how_it_works

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Used by Heroku/uptime monitors and the post-deploy smoke check.
  get "up" => "rails/health#show", as: :rails_health_check
end
