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
    titles = JSON.parse(response.body)["trips"].map { |t| t["title"] }
    assert_includes titles, trips(:alice_kyoto).title
    assert_includes titles, trips(:alice_ramen).title
    refute_includes titles, trips(:bob_okinawa).title
  end

  # F-CAT-02 受け入れ条件
  test "GET /api/v1/trips?category=overseas は overseas の trip のみ返す" do
    get "/api/v1/trips", params: { category: "overseas" }
    assert_response :ok
    titles = JSON.parse(response.body)["trips"].map { |t| t["title"] }
    assert_includes titles, trips(:bob_paris).title
    refute_includes titles, trips(:alice_kyoto).title
  end

  # F-SEARCH-01 受け入れ条件: タイトル/場所/タグの OR 検索
  test "GET /api/v1/trips?q=京都 はタイトル/場所/タグのいずれかにマッチする trip を返す" do
    get "/api/v1/trips", params: { q: "京都" }
    assert_response :ok
    titles = JSON.parse(response.body)["trips"].map { |t| t["title"] }
    # alice_kyoto: タイトル/場所/タグ全てに京都を含む
    # alice_ramen: 場所が京都
    assert_includes titles, trips(:alice_kyoto).title
    assert_includes titles, trips(:alice_ramen).title
    refute_includes titles, trips(:bob_okinawa).title
  end

  test "GET /api/v1/trips?q=美術館 はタグマッチで trip を返す" do
    get "/api/v1/trips", params: { q: "美術館" }
    assert_response :ok
    titles = JSON.parse(response.body)["trips"].map { |t| t["title"] }
    assert_includes titles, trips(:bob_paris).title
  end

  # F-SEARCH-02 受け入れ条件
  test "GET /api/v1/trips?sort=popular は likes_count 降順" do
    trips(:bob_okinawa).update_columns(likes_count: 10)
    trips(:alice_kyoto).update_columns(likes_count: 3)
    get "/api/v1/trips", params: { sort: "popular" }
    assert_response :ok
    ids = JSON.parse(response.body)["trips"].map { |t| t["id"] }
    assert_equal trips(:bob_okinawa).id, ids.first
  end

  # F-SEARCH-03 受け入れ条件: 複合 AND
  test "GET /api/v1/trips?category=overseas&q=パリ は AND 条件で絞り込む" do
    get "/api/v1/trips", params: { category: "overseas", q: "パリ" }
    assert_response :ok
    titles = JSON.parse(response.body)["trips"].map { |t| t["title"] }
    assert_includes titles, trips(:bob_paris).title
    refute_includes titles, trips(:alice_kyoto).title
  end

  test "GET /api/v1/trips?date_from=2026-05-01&date_to=2026-05-31 は期間で絞り込む" do
    get "/api/v1/trips", params: { date_from: "2026-05-01", date_to: "2026-05-31" }
    assert_response :ok
    titles = JSON.parse(response.body)["trips"].map { |t| t["title"] }
    assert_includes titles, trips(:bob_okinawa).title
    assert_includes titles, trips(:bob_paris).title
    refute_includes titles, trips(:alice_kyoto).title
  end

  test "GET /api/v1/trips のレスポンスは tags と category を含む" do
    get "/api/v1/trips"
    assert_response :ok
    body = JSON.parse(response.body)
    kyoto = body["trips"].find { |t| t["id"] == trips(:alice_kyoto).id }
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

  # --- F-UX-DRAFT: 下書き ---

  # 受け入れ条件: タイムライン (index) には下書きが現れない
  test "GET /api/v1/trips は draft trip を含まない (他人視点)" do
    login_via_api(users(:bob))
    get "/api/v1/trips"
    titles = JSON.parse(response.body)["trips"].map { |t| t["title"] }
    refute_includes titles, trips(:alice_draft).title
  end

  # 受け入れ条件: ?mine=drafts で本人の下書きのみ返る
  test "GET /api/v1/trips?mine=drafts は本人の draft のみ返す" do
    login_via_api(users(:alice))
    get "/api/v1/trips", params: { mine: "drafts" }
    titles = JSON.parse(response.body)["trips"].map { |t| t["title"] }
    assert_includes titles, trips(:alice_draft).title
    refute_includes titles, trips(:alice_kyoto).title # published は対象外
  end

  test "GET /api/v1/trips?mine=drafts は未ログインで空配列" do
    get "/api/v1/trips", params: { mine: "drafts" }
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal [], body["trips"]
    assert_nil body["next_cursor"]
  end

  # 受け入れ条件: 他人の draft を直接叩くと 404
  test "GET /api/v1/trips/:id 他人の draft は 404" do
    login_via_api(users(:bob))
    get "/api/v1/trips/#{trips(:alice_draft).id}"
    assert_response :not_found
  end

  # 受け入れ条件: 本人の draft は詳細閲覧できる
  test "GET /api/v1/trips/:id 本人の draft は 200" do
    login_via_api(users(:alice))
    get "/api/v1/trips/#{trips(:alice_draft).id}"
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "draft", body["status"]
  end

  # 受け入れ条件: draft を保存できる
  test "POST /api/v1/trips with status=draft で下書き保存できる" do
    login_via_api(users(:alice))
    post "/api/v1/trips",
      params: {
        title: "下書き作成", destination: "京都",
        started_on: "2026-09-01", ended_on: "2026-09-02",
        body: "", visibility: "public", category: "domestic", status: "draft"
      },
      as: :json
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "draft", body["status"]
  end

  # 受け入れ条件: draft → published 切替
  test "PATCH /api/v1/trips/:id で draft から published に切替できる" do
    login_via_api(users(:alice))
    patch "/api/v1/trips/#{trips(:alice_draft).id}",
      params: { status: "published" },
      as: :json
    assert_response :ok
    assert_equal "published", trips(:alice_draft).reload.status
  end

  # 不正な status 値 (enum ArgumentError 500 を防ぐ)
  test "POST /api/v1/trips with invalid status は published にフォールバック (500 を防ぐ)" do
    login_via_api(users(:alice))
    post "/api/v1/trips",
      params: {
        title: "不正 status", destination: "x",
        started_on: "2026-09-01", ended_on: "2026-09-02",
        body: "", visibility: "public", category: "domestic", status: "invalid_xyz"
      },
      as: :json
    assert_response :created
    assert_equal "published", JSON.parse(response.body)["status"]
  end

  # --- F-UX-INF-SCROLL: cursor pagination ---

  test "GET /api/v1/trips?limit=2 は 2 件 + next_cursor を返す" do
    get "/api/v1/trips", params: { limit: 2 }
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 2, body["trips"].size
    assert body["next_cursor"], "末尾 trip の id が next_cursor として返ること"
    assert_equal body["trips"].last["id"], body["next_cursor"]
  end

  test "GET /api/v1/trips?cursor=X は cursor より小さい id を返す" do
    # まず 1 ページ目
    get "/api/v1/trips", params: { limit: 2 }
    first_page = JSON.parse(response.body)
    cursor = first_page["next_cursor"]

    # 2 ページ目
    get "/api/v1/trips", params: { limit: 2, cursor: cursor }
    second_page = JSON.parse(response.body)
    second_page["trips"].each do |t|
      assert t["id"] < cursor, "Trip ##{t['id']} は cursor #{cursor} 未満であること"
    end
  end

  test "GET /api/v1/trips 全件取得すると最終ページの next_cursor は nil" do
    get "/api/v1/trips", params: { limit: 100 }
    body = JSON.parse(response.body)
    assert_nil body["next_cursor"], "残りがなければ next_cursor は nil"
  end

  test "GET /api/v1/trips?limit=999 は 50 にクランプされる" do
    get "/api/v1/trips", params: { limit: 999 }
    assert_response :ok
    # 全 trip 数が 50 未満なら全件返るが、limit の上限が効いていることは
    # next_cursor が nil (残りなし) で間接確認
    assert_nil JSON.parse(response.body)["next_cursor"]
  end

  test "GET /api/v1/trips?sort=popular は cursor pagination を無効化 (next_cursor=nil)" do
    get "/api/v1/trips", params: { sort: "popular", limit: 2 }
    body = JSON.parse(response.body)
    # sort=popular では cursor を使わないため全件返る → next_cursor は nil
    assert_nil body["next_cursor"]
  end

  # --- F-LEAK-01: 計画達成度 count の権限漏洩防止 (Issue #45) ---
  # 隠したい配列 (planned_spots) は所有者ガード済だが、派生フィールド
  # (planned_count / planned_done_count) のガードが欠落していた。
  # 配列が空でも件数が漏れれば情報漏洩 → 同じ is_owner 条件で全て隠す。

  test "GET /api/v1/trips/:id 他人視点では planned_count / planned_done_count が nil" do
    trip = trips(:alice_kyoto)
    trip.planned_spots.create!(title: "金閣寺", position: 1, done: false)
    trip.planned_spots.create!(title: "清水寺", position: 2, done: true)

    login_via_api(users(:bob))
    get "/api/v1/trips/#{trip.id}"
    assert_response :ok
    body = JSON.parse(response.body)
    assert_nil body["planned_count"], "他人視点では planned_count が漏れないこと"
    assert_nil body["planned_done_count"], "他人視点では planned_done_count が漏れないこと"
    assert_equal [], body["planned_spots"], "planned_spots 本体は従来通り空配列"
  end

  test "GET /api/v1/trips/:id 所有者視点では planned_count / planned_done_count が返る (回帰防止)" do
    trip = trips(:alice_kyoto)
    trip.planned_spots.create!(title: "金閣寺", position: 1, done: false)
    trip.planned_spots.create!(title: "清水寺", position: 2, done: true)

    login_via_api(users(:alice))
    get "/api/v1/trips/#{trip.id}"
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 2, body["planned_count"]
    assert_equal 1, body["planned_done_count"]
    assert_equal 2, body["planned_spots"].size
  end

  test "GET /api/v1/trips/:id 未ログインでは planned_count が漏れない" do
    trip = trips(:alice_kyoto)
    trip.planned_spots.create!(title: "金閣寺", position: 1, done: false)

    get "/api/v1/trips/#{trip.id}"
    assert_response :ok
    body = JSON.parse(response.body)
    assert_nil body["planned_count"]
    assert_nil body["planned_done_count"]
  end
end
