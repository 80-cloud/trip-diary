require "test_helper"

class Api::V1::FavoritesControllerTest < ActionDispatch::IntegrationTest
  # F-FAV-01 受け入れ条件
  test "POST /api/v1/trips/:id/favorite で favorites に 1 件作成 (201)" do
    login_via_api(users(:bob))
    assert_difference -> { Favorite.count }, 1 do
      post "/api/v1/trips/#{trips(:alice_kyoto).id}/favorite"
    end
    assert_response :created
    assert JSON.parse(response.body)["favorited"]
  end

  test "POST 再呼び出しは冪等 (200, 重複作成しない)" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_kyoto).id}/favorite"
    assert_no_difference -> { Favorite.count } do
      post "/api/v1/trips/#{trips(:alice_kyoto).id}/favorite"
    end
    assert_response :ok
  end

  test "DELETE /api/v1/trips/:id/favorite で削除 (favorited=false)" do
    login_via_api(users(:bob))
    Favorite.create!(user: users(:bob), trip: trips(:alice_kyoto))
    assert_difference -> { Favorite.count }, -1 do
      delete "/api/v1/trips/#{trips(:alice_kyoto).id}/favorite"
    end
    refute JSON.parse(response.body)["favorited"]
  end

  test "DELETE が無いお気に入りでも 200 (冪等)" do
    login_via_api(users(:bob))
    assert_no_difference -> { Favorite.count } do
      delete "/api/v1/trips/#{trips(:alice_kyoto).id}/favorite"
    end
    assert_response :ok
  end

  test "他人の draft trip にお気に入り → 404 (visible_to で守る)" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_draft).id}/favorite"
    assert_response :not_found
  end

  test "他人の private trip にお気に入り → 404" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_private).id}/favorite"
    assert_response :not_found
  end

  test "未ログインで POST → 401" do
    post "/api/v1/trips/#{trips(:alice_kyoto).id}/favorite"
    assert_response :unauthorized
  end

  # GET /api/v1/favorites
  test "GET /api/v1/favorites は自分のお気に入りのみ返す (新しい順)" do
    Favorite.create!(user: users(:bob), trip: trips(:alice_kyoto), created_at: 1.day.ago)
    Favorite.create!(user: users(:bob), trip: trips(:alice_ramen), created_at: 1.minute.ago)
    Favorite.create!(user: users(:carol), trip: trips(:bob_okinawa)) # 他人のお気に入り

    login_via_api(users(:bob))
    get "/api/v1/favorites"
    assert_response :ok
    ids = JSON.parse(response.body).map { |t| t["id"] }
    assert_equal [trips(:alice_ramen).id, trips(:alice_kyoto).id], ids, "新しい順 + 他人の favorites は含まない"
  end

  test "GET /api/v1/favorites は登録後に投稿者が private 化した trip を返さない" do
    Favorite.create!(user: users(:bob), trip: trips(:alice_kyoto))
    trips(:alice_kyoto).update!(visibility: "private")
    login_via_api(users(:bob))
    get "/api/v1/favorites"
    ids = JSON.parse(response.body).map { |t| t["id"] }
    refute_includes ids, trips(:alice_kyoto).id
  end

  test "trip 詳細 API は favorited_by_me を含む (ログイン時)" do
    Favorite.create!(user: users(:bob), trip: trips(:alice_kyoto))
    login_via_api(users(:bob))
    get "/api/v1/trips/#{trips(:alice_kyoto).id}"
    body = JSON.parse(response.body)
    assert_equal true, body["favorited_by_me"]
  end

  test "trip 詳細 API は favorited_by_me=false (未ログイン時)" do
    get "/api/v1/trips/#{trips(:alice_kyoto).id}"
    body = JSON.parse(response.body)
    assert_equal false, body["favorited_by_me"]
  end
end
