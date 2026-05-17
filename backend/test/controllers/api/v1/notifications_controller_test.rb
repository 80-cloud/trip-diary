require "test_helper"

class Api::V1::NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @trip  = trips(:alice_kyoto)
  end

  # ===== GET /api/v1/notifications =====

  test "未ログインで GET /notifications → 401" do
    get "/api/v1/notifications"
    assert_response :unauthorized
  end

  test "GET /notifications は自分宛のみ返す (他人宛は含まない)" do
    mine    = Notification.create!(recipient: @alice, actor: @bob,   target: @trip, verb: "commented")
    others  = Notification.create!(recipient: @bob,   actor: @alice, target: @trip, verb: "liked")

    login_via_api(@alice)
    get "/api/v1/notifications"
    assert_response :ok
    body = JSON.parse(response.body)
    ids = body["notifications"].map { |n| n["id"] }
    assert_includes ids, mine.id
    refute_includes ids, others.id
  end

  test "GET /notifications は created_at 降順" do
    older = Notification.create!(recipient: @alice, actor: @bob, target: @trip, verb: "commented", created_at: 2.hours.ago)
    newer = Notification.create!(recipient: @alice, actor: @bob, target: @trip, verb: "liked",     created_at: 1.minute.ago)

    login_via_api(@alice)
    get "/api/v1/notifications"
    body = JSON.parse(response.body)
    assert_equal [newer.id, older.id], body["notifications"].map { |n| n["id"] }
  end

  test "GET /notifications は最新 50 件まで" do
    # 55 件を bulk insert (validation/uniqueness を bypass。pagination 検証用)
    now = Time.current
    rows = 55.times.map do |i|
      {
        recipient_id: @alice.id, actor_id: @bob.id,
        verb: "commented", target_type: "Trip", target_id: @trip.id,
        created_at: (60 - i).minutes.ago, updated_at: now
      }
    end
    Notification.insert_all(rows)

    login_via_api(@alice)
    get "/api/v1/notifications"
    body = JSON.parse(response.body)
    assert_equal 50, body["notifications"].size
  end

  test "GET /notifications は unread_count を返す" do
    Notification.create!(recipient: @alice, actor: @bob, target: @trip, verb: "commented")
    Notification.create!(recipient: @alice, actor: @bob, target: @trip, verb: "liked", read_at: Time.current)

    login_via_api(@alice)
    get "/api/v1/notifications"
    body = JSON.parse(response.body)
    assert_equal 1, body["unread_count"]
  end

  test "Comment 通知は trip_id を含む" do
    comment = Comment.create!(trip: @trip, user: @bob, body: "テスト") # hook で notification 作成
    login_via_api(@alice)
    get "/api/v1/notifications"
    body = JSON.parse(response.body)
    n = body["notifications"].first
    assert_equal "Comment", n["target_type"]
    assert_equal @trip.id,  n["trip_id"]
    assert_equal @bob.id,   n["actor"]["id"]
  end

  test "Follow 通知は trip_id を含まない" do
    Follow.create!(follower: @bob, followed: @alice) # hook で followed 通知作成
    login_via_api(@alice)
    get "/api/v1/notifications"
    body = JSON.parse(response.body)
    n = body["notifications"].first
    assert_equal "Follow", n["target_type"]
    refute n.key?("trip_id"), "Follow 通知は trip_id キーを含まない"
  end

  # ===== GET /api/v1/notifications/unread_count =====

  test "未ログインで GET /notifications/unread_count → 401" do
    get "/api/v1/notifications/unread_count"
    assert_response :unauthorized
  end

  test "unread_count は未読のみカウント" do
    Notification.create!(recipient: @alice, actor: @bob, target: @trip, verb: "commented")
    Notification.create!(recipient: @alice, actor: @bob, target: @trip, verb: "liked", read_at: Time.current)
    # 他人宛は含まない
    Notification.create!(recipient: @bob, actor: @alice, target: @trip, verb: "commented")

    login_via_api(@alice)
    get "/api/v1/notifications/unread_count"
    assert_response :ok
    assert_equal 1, JSON.parse(response.body)["unread_count"]
  end

  # ===== PATCH /api/v1/notifications/:id =====

  test "未ログインで PATCH → 401" do
    n = Notification.create!(recipient: @alice, actor: @bob, target: @trip, verb: "commented")
    patch "/api/v1/notifications/#{n.id}"
    assert_response :unauthorized
  end

  test "PATCH 自分の通知 → read_at がセットされる" do
    n = Notification.create!(recipient: @alice, actor: @bob, target: @trip, verb: "commented")
    assert_nil n.read_at

    login_via_api(@alice)
    patch "/api/v1/notifications/#{n.id}"
    assert_response :ok
    body = JSON.parse(response.body)
    assert_not_nil body["read_at"]
    assert_not_nil n.reload.read_at
  end

  test "PATCH 他人の通知 → 404 (存在性を漏らさない / E-H1 整合)" do
    others = Notification.create!(recipient: @bob, actor: @alice, target: @trip, verb: "commented")
    login_via_api(@alice)
    patch "/api/v1/notifications/#{others.id}"
    assert_response :not_found
    assert_nil others.reload.read_at  # 既読化されていない
  end

  test "PATCH 既読の通知 → no-op (read_at 変わらず) / 200" do
    t = 1.day.ago
    n = Notification.create!(recipient: @alice, actor: @bob, target: @trip, verb: "commented", read_at: t)
    login_via_api(@alice)
    patch "/api/v1/notifications/#{n.id}"
    assert_response :ok
    assert_in_delta t.to_i, n.reload.read_at.to_i, 1
  end

  test "PATCH 存在しない id → 404" do
    login_via_api(@alice)
    patch "/api/v1/notifications/999999"
    assert_response :not_found
  end

  # ===== POST /api/v1/notifications/read_all =====

  test "未ログインで POST /read_all → 401" do
    post "/api/v1/notifications/read_all"
    assert_response :unauthorized
  end

  test "POST /read_all で自分の未読通知が全て既読化される" do
    n1 = Notification.create!(recipient: @alice, actor: @bob, target: @trip, verb: "commented")
    n2 = Notification.create!(recipient: @alice, actor: @bob, target: @trip, verb: "liked")
    # 他人の通知は影響を受けない
    other = Notification.create!(recipient: @bob, actor: @alice, target: @trip, verb: "commented")

    login_via_api(@alice)
    post "/api/v1/notifications/read_all"
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 2, body["read_count"]
    assert_equal 0, body["unread_count"]

    assert_not_nil n1.reload.read_at
    assert_not_nil n2.reload.read_at
    assert_nil     other.reload.read_at, "他人の通知は更新されない"
  end

  test "POST /read_all は未読がなくても 200 / read_count=0" do
    login_via_api(@alice)
    post "/api/v1/notifications/read_all"
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 0, body["read_count"]
  end
end
