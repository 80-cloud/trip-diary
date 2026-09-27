require "test_helper"

# F-GUEST-01: ゲストの行動の見え方 (Issue #111)
# ゲストのコメントとフォロー関係は、そのゲスト本人にだけ見せる。
# 受け入れ条件は Issue #111 と docs/公開デモ化計画書.md §5-3 に対応する。
class Api::V1::GuestVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @demo = User.create!(email: "sakura@#{User::DEMO_EMAIL_DOMAIN}", password: "password123", display_name: "sakura")
    @trip = @demo.trips.create!(title: "デモの旅", destination: "函館",
                                started_on: "2026-08-01", ended_on: "2026-08-02",
                                visibility: "public", category: "domestic", tag_list: [ "函館" ])
    Comment.create!(trip: @trip, user: users(:carol), body: "楽しそう")
  end

  test "未ログインの閲覧者には、ゲストのコメントが返らず件数にも含まれない" do
    guest_login_and_comment
    delete "/api/v1/logout"

    detail = trip_detail
    assert_equal [ "楽しそう" ], detail["comments"].map { |c| c["body"] }
    assert_equal 1, detail["comments_count"]
    assert_equal 1, listed_comments_count
  end

  test "ゲスト本人には自分のコメントが返り、件数はゲスト以外 + 自分になる" do
    guest_login_and_comment

    detail = trip_detail
    assert_equal [ "楽しそう", "ゲストです" ], detail["comments"].map { |c| c["body"] }
    assert_equal 2, detail["comments_count"]
    assert_equal 2, listed_comments_count
  end

  test "別のゲストには、最初のゲストのコメントが返らず件数にも含まれない" do
    guest_login_and_comment
    post "/api/v1/guest_login"

    detail = trip_detail
    assert_equal [ "楽しそう" ], detail["comments"].map { |c| c["body"] }
    assert_equal 1, detail["comments_count"]
    assert_equal 1, listed_comments_count
  end

  test "タグ別一覧とお気に入り一覧の件数が、詳細の件数と一致する" do
    guest_login_and_comment
    post "/api/v1/trips/#{@trip.id}/favorite"

    assert_equal 2, trip_detail["comments_count"]
    assert_equal 2, tag_comments_count
    get "/api/v1/favorites"
    assert_equal 2, JSON.parse(response.body).first["comments_count"]

    delete "/api/v1/logout"
    assert_equal 1, trip_detail["comments_count"]
    assert_equal 1, tag_comments_count
  end

  test "未ログインの閲覧者には、デモユーザーのフォロー中・フォロワー一覧にゲストが含まれない" do
    Follow.create!(follower: users(:carol), followed: @demo)
    Follow.create!(follower: @demo, followed: users(:carol))
    post "/api/v1/guest_login"
    post "/api/v1/users/#{@demo.id}/follow"
    delete "/api/v1/logout"

    %w[following followers].each do |type|
      assert_equal [ users(:carol).id ], follow_list_ids(@demo, type), type
    end
  end

  test "ゲスト本人には、自分のフォロー一覧とデモユーザーの一覧が通常どおり見える" do
    post "/api/v1/guest_login"
    guest = User.find(JSON.parse(response.body).dig("user", "id"))
    post "/api/v1/users/#{@demo.id}/follow"

    assert_equal [ @demo.id ], follow_list_ids(guest, "followers")
    assert_equal [ @demo.id ], follow_list_ids(guest, "following")
    assert_equal [ guest.id ], follow_list_ids(@demo, "followers")
    assert_equal [ guest.id ], follow_list_ids(@demo, "following")
  end

  private

  # ゲストでログインし、デモ旅行にコメントする
  def guest_login_and_comment
    post "/api/v1/guest_login"
    post "/api/v1/trips/#{@trip.id}/comments", params: { body: "ゲストです" }
    assert_response :created
  end

  def trip_detail
    get "/api/v1/trips/#{@trip.id}"
    JSON.parse(response.body)
  end

  def listed_comments_count
    get "/api/v1/trips"
    JSON.parse(response.body)["trips"].find { |t| t["id"] == @trip.id }["comments_count"]
  end

  def tag_comments_count
    get "/api/v1/tags/#{ERB::Util.url_encode("函館")}"
    JSON.parse(response.body)["trips"].first["comments_count"]
  end

  def follow_list_ids(user, type)
    get "/api/v1/users/#{user.id}/follows", params: { type: type }
    JSON.parse(response.body).map { |u| u["id"] }
  end
end
