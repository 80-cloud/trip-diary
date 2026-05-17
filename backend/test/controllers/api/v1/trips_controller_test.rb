require "test_helper"

class Api::V1::TripsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # 検索/絞り込みテスト用に各 trip にタグを付与
    trips(:alice_kyoto).update!(tag_list: ["京都", "桜"])
    trips(:bob_okinawa).update!(tag_list: ["海", "夏"])
    trips(:bob_paris).update!(tag_list: ["海外", "美術館"])
    trips(:alice_ramen).update!(tag_list: ["京都", "ラーメン"])
  end

  # F-TAG-02 受け入れ条件
  test "GET /api/v1/trips?tag=京都 はタグ「京都」の trip のみ返す" do
    get "/api/v1/trips", params: { tag: "京都" }
    assert_response :ok
    titles = JSON.parse(response.body).map { |t| t["title"] }
    assert_includes titles, trips(:alice_kyoto).title
    assert_includes titles, trips(:alice_ramen).title
    refute_includes titles, trips(:bob_okinawa).title
  end

  # F-CAT-02 受け入れ条件
  test "GET /api/v1/trips?category=overseas は overseas の trip のみ返す" do
    get "/api/v1/trips", params: { category: "overseas" }
    assert_response :ok
    titles = JSON.parse(response.body).map { |t| t["title"] }
    assert_includes titles, trips(:bob_paris).title
    refute_includes titles, trips(:alice_kyoto).title
  end

  # F-SEARCH-01 受け入れ条件: タイトル/場所/タグの OR 検索
  test "GET /api/v1/trips?q=京都 はタイトル/場所/タグのいずれかにマッチする trip を返す" do
    get "/api/v1/trips", params: { q: "京都" }
    assert_response :ok
    titles = JSON.parse(response.body).map { |t| t["title"] }
    # alice_kyoto: タイトル/場所/タグ全てに京都を含む
    # alice_ramen: 場所が京都
    assert_includes titles, trips(:alice_kyoto).title
    assert_includes titles, trips(:alice_ramen).title
    refute_includes titles, trips(:bob_okinawa).title
  end

  test "GET /api/v1/trips?q=美術館 はタグマッチで trip を返す" do
    get "/api/v1/trips", params: { q: "美術館" }
    assert_response :ok
    titles = JSON.parse(response.body).map { |t| t["title"] }
    assert_includes titles, trips(:bob_paris).title
  end

  # F-SEARCH-02 受け入れ条件
  test "GET /api/v1/trips?sort=popular は likes_count 降順" do
    trips(:bob_okinawa).update_columns(likes_count: 10)
    trips(:alice_kyoto).update_columns(likes_count: 3)
    get "/api/v1/trips", params: { sort: "popular" }
    assert_response :ok
    ids = JSON.parse(response.body).map { |t| t["id"] }
    assert_equal trips(:bob_okinawa).id, ids.first
  end

  # F-SEARCH-03 受け入れ条件: 複合 AND
  test "GET /api/v1/trips?category=overseas&q=パリ は AND 条件で絞り込む" do
    get "/api/v1/trips", params: { category: "overseas", q: "パリ" }
    assert_response :ok
    titles = JSON.parse(response.body).map { |t| t["title"] }
    assert_includes titles, trips(:bob_paris).title
    refute_includes titles, trips(:alice_kyoto).title
  end

  test "GET /api/v1/trips?date_from=2026-05-01&date_to=2026-05-31 は期間で絞り込む" do
    get "/api/v1/trips", params: { date_from: "2026-05-01", date_to: "2026-05-31" }
    assert_response :ok
    titles = JSON.parse(response.body).map { |t| t["title"] }
    assert_includes titles, trips(:bob_okinawa).title
    assert_includes titles, trips(:bob_paris).title
    refute_includes titles, trips(:alice_kyoto).title
  end

  test "GET /api/v1/trips のレスポンスは tags と category を含む" do
    get "/api/v1/trips"
    assert_response :ok
    body = JSON.parse(response.body)
    kyoto = body.find { |t| t["id"] == trips(:alice_kyoto).id }
    assert kyoto, "alice_kyoto が返されていること"
    assert_includes kyoto["tags"], "京都"
    assert_equal "domestic", kyoto["category"]
  end

  # F-TAG-01 受け入れ条件
  test "POST /api/v1/trips with tag_list で複数タグが付与される" do
    login_via_api(users(:alice))
    assert_difference "Tag.count", 3 do
      post "/api/v1/trips",
        params: {
          title: "新規旅行", destination: "札幌",
          started_on: "2026-08-01", ended_on: "2026-08-03",
          body: "雪まつり", visibility: "public", category: "domestic",
          tag_list: ["雪", "北海道", "祭"]
        },
        as: :json
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal %w[雪 北海道 祭].sort, body["tags"].sort
  end

  test "POST /api/v1/trips with tag_list は既存タグを再利用する" do
    Tag.create!(name: "既存タグ")
    login_via_api(users(:alice))
    assert_difference "Tag.count", 1 do # "新規タグ" のみ追加
      post "/api/v1/trips",
        params: {
          title: "再利用テスト", destination: "東京",
          started_on: "2026-08-01", ended_on: "2026-08-02",
          body: "", visibility: "public", category: "domestic",
          tag_list: ["既存タグ", "新規タグ"]
        },
        as: :json
    end
    assert_response :created
  end

  test "POST /api/v1/trips with no category は 422" do
    login_via_api(users(:alice))
    post "/api/v1/trips",
      params: {
        title: "カテゴリなし", destination: "東京",
        started_on: "2026-08-01", ended_on: "2026-08-02",
        body: "", visibility: "public"
      },
      as: :json
    assert_response :unprocessable_entity
  end

  # enum setter は不正値で ArgumentError を上げる (= デフォルト 500)。
  # controller 側で sanitize して 422 にしていることを保証する。
  test "POST /api/v1/trips with invalid category は 500 ではなく 422" do
    login_via_api(users(:alice))
    post "/api/v1/trips",
      params: {
        title: "不正カテゴリ", destination: "東京",
        started_on: "2026-08-01", ended_on: "2026-08-02",
        body: "", visibility: "public", category: "invalid_xyz"
      },
      as: :json
    assert_response :unprocessable_entity
  end

  test "POST /api/v1/trips with empty category は 422" do
    login_via_api(users(:alice))
    post "/api/v1/trips",
      params: {
        title: "空カテゴリ", destination: "東京",
        started_on: "2026-08-01", ended_on: "2026-08-02",
        body: "", visibility: "public", category: ""
      },
      as: :json
    assert_response :unprocessable_entity
  end
end
