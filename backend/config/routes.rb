Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      get  "health",  to: "health#show"
      post "signup",  to: "auth#signup"
      post "login",   to: "auth#login"
      delete "logout", to: "auth#logout"
      get  "me",      to: "auth#me"

      resources :trips do
        resources :comments, only: [:create, :destroy]
        resource  :like,    only: [:create, :destroy]
      end
    end
  end
end
