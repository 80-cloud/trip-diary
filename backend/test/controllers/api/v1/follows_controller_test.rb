require "test_helper"

class Api::V1::FollowsControllerTest < ActionDispatch::IntegrationTest
  # F-FOLLOW-01
  test "POST /users/:id/follow で 201 + フォロー成立" do
    login_via_api(users(:alice))
    assert_difference -> { Follow.count }, 1 do
      post "/api/v1/users/#{users(:bob).id}/follow"
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert body["following"]
  end

  test "POST 再呼び出しは冪等 (200)" do
    login_via_api(users(:alice))
    Follow.create!(follower: users(:alice), followed: users(:bob))
    assert_no_difference -> { Follow.count } do
      post "/api/v1/users/#{users(:bob).id}/follow"
    end
    assert_response :ok
  end

  test "自分自身をフォロー → 422" do
    login_via_api(users(:alice))
    post "/api/v1/users/#{users(:alice).id}/follow"
    assert_response :unprocessable_entity
  end

  test "未ログインで POST → 401" do
    post "/api/v1/users/#{users(:bob).id}/follow"
    assert_response :unauthorized
  end

  # F-FOLLOW-02
  test "DELETE でアンフォロー" do
    Follow.create!(follower: users(:alice), followed: users(:bob))
    login_via_api(users(:alice))
    assert_difference -> { Follow.count }, -1 do
      delete "/api/v1/users/#{users(:bob).id}/follow"
    end
    refute JSON.parse(response.body)["following"]
  end

  test "DELETE が無くても 200 (冪等)" do
    login_via_api(users(:alice))
    assert_no_difference -> { Follow.count } do
      delete "/api/v1/users/#{users(:bob).id}/follow"
    end
    assert_response :ok
  end

  # F-FOLLOW-03
  test "GET /users/:id/follows?type=following は alice のフォロー中ユーザー" do
    Follow.create!(follower: users(:alice), followed: users(:bob))
    Follow.create!(follower: users(:alice), followed: users(:carol))
    get "/api/v1/users/#{users(:alice).id}/follows", params: { type: "following" }
    assert_response :ok
    names = JSON.parse(response.body).map { |u| u["display_name"] }
    assert_includes names, "Bob"
    assert_includes names, "Carol"
  end

  test "GET /users/:id/follows?type=followers は alice のフォロワー" do
    Follow.create!(follower: users(:bob),   followed: users(:alice))
    Follow.create!(follower: users(:carol), followed: users(:alice))
    get "/api/v1/users/#{users(:alice).id}/follows", params: { type: "followers" }
    names = JSON.parse(response.body).map { |u| u["display_name"] }
    assert_includes names, "Bob"
    assert_includes names, "Carol"
  end

  test "follows レスポンスは followed_by_me を含む (ログイン時)" do
    Follow.create!(follower: users(:alice), followed: users(:bob))
    Follow.create!(follower: users(:alice), followed: users(:carol))
    login_via_api(users(:alice))
    # bob だけフォロー、carol はフォローしていない状況にする (一度 Follow を作って戻す)
    # 既存: alice → bob, alice → carol。carol を解除
    Follow.where(follower: users(:alice), followed: users(:carol)).delete_all
    get "/api/v1/users/#{users(:bob).id}/follows", params: { type: "followers" }
    # bob のフォロワー = alice (が含まれる)
    body = JSON.parse(response.body)
    alice_entry = body.find { |u| u["id"] == users(:alice).id }
    assert alice_entry
    assert_equal false, alice_entry["followed_by_me"], "alice 自身は自分をフォローしていない"
  end

  # F-FOLLOW-04: ?mine=following タイムライン
  test "GET /trips?mine=following は自分がフォロー中ユーザーの trip のみ返す" do
    # bob と carol が trip を持つ。alice は bob のみフォロー。
    Follow.create!(follower: users(:alice), followed: users(:bob))
    login_via_api(users(:alice))
    get "/api/v1/trips", params: { mine: "following" }
    body = JSON.parse(response.body)
    user_ids = body["trips"].map { |t| t["user"]["id"] }.uniq
    assert_includes user_ids, users(:bob).id
    refute_includes user_ids, users(:carol).id  # carol はフォローしていない
    refute_includes user_ids, users(:alice).id  # 自分の trip も含まない
  end

  test "GET /trips?mine=following は未ログインで空配列" do
    get "/api/v1/trips", params: { mine: "following" }
    body = JSON.parse(response.body)
    assert_equal [], body["trips"]
  end

  # trip 詳細レスポンスの user.followed_by_me
  test "trip 詳細の user.followed_by_me がフォロー関係を反映する" do
    Follow.create!(follower: users(:alice), followed: users(:bob))
    login_via_api(users(:alice))
    get "/api/v1/trips/#{trips(:bob_okinawa).id}"
    body = JSON.parse(response.body)
    assert_equal true, body["user"]["followed_by_me"]
  end

  test "trip 詳細の user.followed_by_me は未ログイン時 false" do
    get "/api/v1/trips/#{trips(:bob_okinawa).id}"
    body = JSON.parse(response.body)
    assert_equal false, body["user"]["followed_by_me"]
  end
end
