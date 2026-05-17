Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      get  "health",  to: "health#show"
      post "signup",  to: "auth#signup"
      post "login",   to: "auth#login"
      delete "logout", to: "auth#logout"
      get   "me",     to: "auth#me"
      patch "me",     to: "auth#update_me"
      put   "me",     to: "auth#update_me"

      resources :trips do
        resources :comments, only: [ :create, :destroy ]
        resource  :like,    only: [ :create, :destroy ]
        # 各 trip に対する favorite (PUT で冪等トグル ON、DELETE で OFF)
        resource  :favorite, only: [ :create, :destroy ], controller: "favorites"
        # 各 trip に対する個人メモ (PUT で upsert、DELETE で削除)
        resource  :memo,     only: [ :update, :destroy ], controller: "memos"
        # F-PLAN-01/02: 計画スポット (本人のみ CRUD)
        resources :planned_spots, only: [ :create, :update, :destroy ]
        # F-PACK-01: 持ち物チェックリスト (本人のみ CRUD)
        resources :packing_items, only: [ :create, :update, :destroy ]
        # F-TICKET-01: チケット (本人のみ CRUD / ActiveStorage 単体添付)
        resources :tickets, only: [ :create, :update, :destroy ]
        # F-REVIEW-01: 旅行レビュー (1 trip 1 review / PUT upsert)
        resource :review, only: [ :update, :destroy ]
        # F-BUDGET-01: 旅行予算 (1 trip 1 budget / PUT upsert)
        resource :budget, only: [ :update, :destroy ]
        # F-RECEIPT-01: レシート (本人のみ CRUD)
        resources :receipts, only: [ :create, :update, :destroy ]
      end

      # 自分のお気に入り trip 一覧 (本人専用)
      get "favorites", to: "favorites#index"

      # フォロー: POST/DELETE で冪等トグル + GET でフォロー/フォロワー一覧
      resources :users, only: [] do
        resource :follow, only: [ :create, :destroy ], controller: "follows"
        get "follows", to: "follows#index"
      end

      get "tags/popular", to: "tags#popular"
      # タグ名は日本語/記号を含み得る。デフォルトの :id 制約だと「.」「/」で詰まるため
      # constraint で任意文字 (slash 以外) を許容する。
      get "tags/:name",   to: "tags#show", constraints: { name: %r{[^/]+} }

      # F-NOTIF-01/02: 通知センター (本人専用)
      resources :notifications, only: [ :index, :update ] do
        collection do
          get  :unread_count
          post :read_all
        end
      end
    end
  end
end
