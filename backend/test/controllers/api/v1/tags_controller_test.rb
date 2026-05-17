require "test_helper"

class Api::V1::TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    trips(:alice_kyoto).update!(tag_list: [ "京都", "桜" ])
    trips(:alice_ramen).update!(tag_list: [ "京都", "ラーメン" ])
    trips(:bob_okinawa).update!(tag_list: [ "海" ])
  end

  # F-TAG-02 受け入れ条件
  test "GET /api/v1/tags/:name は該当タグの trip 一覧を返す" do
    get "/api/v1/tags/#{ERB::Util.url_encode('京都')}"
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "京都", body.dig("tag", "name")
    titles = body["trips"].map { |t| t["title"] }
    assert_includes titles, trips(:alice_kyoto).title
    assert_includes titles, trips(:alice_ramen).title
    refute_includes titles, trips(:bob_okinawa).title
  end

  test "GET /api/v1/tags/存在しないタグ は 404" do
    get "/api/v1/tags/#{ERB::Util.url_encode('存在しない')}"
    assert_response :not_found
  end

  # F-TAG-03 受け入れ条件
  test "GET /api/v1/tags/popular は trips_count 降順で返す" do
    get "/api/v1/tags/popular"
    assert_response :ok
    body = JSON.parse(response.body)
    # 「京都」は 2 trip / 「桜」「ラーメン」「海」は 1 trip
    assert_equal "京都", body.first["name"]
    assert_equal 2, body.first["trips_count"]
  end

  test "GET /api/v1/tags/popular?limit=2 は件数を制限する" do
    get "/api/v1/tags/popular", params: { limit: 2 }
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 2, body.size
  end

  test "GET /api/v1/tags/:name は非公開 trip を他人に見せない" do
    trips(:alice_private).update!(tag_list: [ "秘密タグ" ])
    # 未ログイン
    get "/api/v1/tags/#{ERB::Util.url_encode('秘密タグ')}"
    assert_response :ok
    titles = JSON.parse(response.body)["trips"].map { |t| t["title"] }
    refute_includes titles, trips(:alice_private).title

    # bob (他人) でログイン
    login_via_api(users(:bob))
    get "/api/v1/tags/#{ERB::Util.url_encode('秘密タグ')}"
    titles = JSON.parse(response.body)["trips"].map { |t| t["title"] }
    refute_includes titles, trips(:alice_private).title
  end
end
