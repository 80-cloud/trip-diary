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
        # 各 trip に対する favorite (PUT で冪等トグル ON、DELETE で OFF)
        resource  :favorite, only: [:create, :destroy], controller: "favorites"
        # 各 trip に対する個人メモ (PUT で upsert、DELETE で削除)
        resource  :memo,     only: [:update, :destroy], controller: "memos"
      end

      # 自分のお気に入り trip 一覧 (本人専用)
      get "favorites", to: "favorites#index"

      # フォロー: POST/DELETE で冪等トグル + GET でフォロー/フォロワー一覧
      resources :users, only: [] do
        resource :follow, only: [:create, :destroy], controller: "follows"
        get "follows", to: "follows#index"
      end

      get "tags/popular", to: "tags#popular"
      # タグ名は日本語/記号を含み得る。デフォルトの :id 制約だと「.」「/」で詰まるため
      # constraint で任意文字 (slash 以外) を許容する。
      get "tags/:name",   to: "tags#show", constraints: { name: %r{[^/]+} }
    end
  end
end
