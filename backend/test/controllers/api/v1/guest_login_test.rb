require "test_helper"

# F-GUEST-01: POST /api/v1/guest_login (Issue #109)
# 訪問者ごとに一時ゲストを作り、24 時間後に削除する。受け入れ条件は Issue #109 と
# docs/公開デモ化計画書.md §5-3 に対応する。
class Api::V1::GuestLoginTest < ActionDispatch::IntegrationTest
  TRIP_PARAMS = {
    title: "ゲストの旅", destination: "札幌",
    started_on: "2026-08-01", ended_on: "2026-08-03",
    visibility: "public", category: "domestic"
  }.freeze

  test "未ログインで guest_login すると 201・Cookie 発行・ゲストが 1 人増える" do
    assert_difference -> { User.guests.count }, 1 do
      post "/api/v1/guest_login"
    end
    assert_response :created
    assert cookies[ApplicationController::COOKIE_NAME.to_s].present?

    user = JSON.parse(response.body)["user"]
    assert_equal true, user["guest"]
    assert user["email"].end_with?("@example.invalid"), user["email"]
    assert_match(/\Aゲスト-\d{4}\z/, user["display_name"])

    get "/api/v1/me"
    assert_equal user["id"], JSON.parse(response.body).dig("user", "id")
  end

  test "デモユーザーのうち id の小さい 2 名がゲストをフォローし、未読通知が 2 件できる" do
    demo_users = %w[sakura kenta yui].map { |key| create_demo_user(key) }

    post "/api/v1/guest_login"
    assert_response :created
    guest = User.find(JSON.parse(response.body).dig("user", "id"))

    assert_equal demo_users.first(2).map(&:id).sort, guest.followers.map(&:id).sort
    get "/api/v1/notifications/unread_count"
    assert_equal 2, JSON.parse(response.body)["unread_count"]
  end

  test "デモユーザーがいなくても 201 で、通知は 0 件" do
    post "/api/v1/guest_login"
    assert_response :created

    get "/api/v1/notifications/unread_count"
    assert_equal 0, JSON.parse(response.body)["unread_count"]
  end

  test "ゲストが public で作った旅行記録は private で保存される" do
    post "/api/v1/guest_login"

    post "/api/v1/trips", params: TRIP_PARAMS, as: :json
    assert_response :created
    assert_equal "private", JSON.parse(response.body)["visibility"]
  end

  test "ゲストが PATCH で public に変えても private のまま" do
    post "/api/v1/guest_login"
    post "/api/v1/trips", params: TRIP_PARAMS, as: :json
    trip_id = JSON.parse(response.body)["id"]

    patch "/api/v1/trips/#{trip_id}", params: { visibility: "public" }, as: :json
    assert_response :ok
    assert_equal "private", Trip.find(trip_id).visibility
  end

  test "通常ユーザーの public はそのまま保存される" do
    login_via_api(users(:alice))

    post "/api/v1/trips", params: TRIP_PARAMS, as: :json
    assert_response :created
    assert_equal "public", JSON.parse(response.body)["visibility"]
  end

  test "期限切れのゲストは次のゲストログインで関連データごと削除され、孤立レコードが残らない" do
    kyoto = trips(:alice_kyoto)
    comments_before = kyoto.reload.comments_count
    expired = User.create_guest!
    expired_trip = expired.trips.create!(TRIP_PARAMS)
    expired.comments.create!(trip: kyoto, body: "ゲストのコメント")
    expired.likes.create!(trip: kyoto)
    expired.favorites.create!(trip: kyoto)
    expired.active_follows.create!(followed: users(:alice))
    users(:alice).active_follows.create!(followed: expired)

    travel 25.hours
    active = User.create_guest!
    post "/api/v1/guest_login"
    assert_response :created

    assert_not User.exists?(expired.id)
    assert_not Trip.exists?(expired_trip.id)
    assert User.exists?(active.id)
    assert_equal comments_before, kyoto.reload.comments_count
    assert_no_orphans
  end

  test "有効なゲストが 200 人いると 503 を返し、ユーザーは増えない" do
    insert_guests(User::GUEST_MAX_ACTIVE, created_at: Time.current)

    assert_no_difference -> { User.count } do
      post "/api/v1/guest_login"
    end
    assert_response :service_unavailable
    assert_match(/混み合って/, JSON.parse(response.body)["error"])
    assert cookies[ApplicationController::COOKIE_NAME.to_s].blank?
  end

  test "期限切れのゲストは上限 200 人に数えない" do
    insert_guests(User::GUEST_MAX_ACTIVE - 1, created_at: Time.current)
    insert_guests(50, created_at: 25.hours.ago)

    post "/api/v1/guest_login"
    assert_response :created
  end

  test "同じ IP から 10 分に 6 回目の guest_login は 429 (rack-attack)" do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
    begin
      5.times do
        post "/api/v1/guest_login"
        assert_response :created
      end
      post "/api/v1/guest_login"
      assert_response :too_many_requests
    ensure
      Rack::Attack.enabled = false
      Rack::Attack.cache.store.clear
    end
  end

  test "通常ユーザーでログイン中に guest_login すると、ゲストの Cookie で上書きされる" do
    login_via_api(users(:alice))

    post "/api/v1/guest_login"
    assert_response :created

    get "/api/v1/me"
    me = JSON.parse(response.body)["user"]
    assert_equal true, me["guest"]
    assert_not_equal users(:alice).id, me["id"]
  end

  private

  def create_demo_user(key)
    User.create!(email: "#{key}@#{User::DEMO_EMAIL_DOMAIN}", password: "password123", display_name: key)
  end

  # 上限のテスト用。1 人ずつ作ると遅いため、関連データの無いゲストをまとめて挿入する
  # (削除ではなく挿入なので、callback を通さなくても孤立レコードは生じない)。
  def insert_guests(count, created_at:)
    rows = Array.new(count) do |i|
      {
        email: "guest-bulk-#{created_at.to_i}-#{i}@example.invalid",
        password_digest: "x", display_name: "ゲスト-0000", guest: true,
        created_at: created_at, updated_at: created_at
      }
    end
    User.insert_all!(rows)
  end

  def assert_no_orphans
    user_ids = User.select(:id)
    {
      "trips" => Trip.where.not(user_id: user_ids),
      "comments" => Comment.where.not(user_id: user_ids),
      "likes" => Like.where.not(user_id: user_ids),
      "favorites" => Favorite.where.not(user_id: user_ids),
      "memos" => Memo.where.not(user_id: user_ids),
      "follows(follower)" => Follow.where.not(follower_id: user_ids),
      "follows(followed)" => Follow.where.not(followed_id: user_ids),
      "notifications(recipient)" => Notification.where.not(recipient_id: user_ids),
      "notifications(actor)" => Notification.where.not(actor_id: user_ids)
    }.each do |name, scope|
      assert_equal 0, scope.count, "#{name} に孤立レコードがある"
    end
  end
end
