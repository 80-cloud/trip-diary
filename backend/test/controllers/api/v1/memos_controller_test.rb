require "test_helper"

class Api::V1::MemosControllerTest < ActionDispatch::IntegrationTest
  # F-MEMO-01 受け入れ条件
  test "PUT /api/v1/trips/:id/memo で新規メモを作成" do
    login_via_api(users(:bob))
    assert_difference -> { Memo.count }, 1 do
      put "/api/v1/trips/#{trips(:alice_kyoto).id}/memo",
        params: { body: "後で行きたい" }, as: :json
    end
    assert_response :ok
    assert_equal "後で行きたい", JSON.parse(response.body)["memo"]
  end

  test "PUT で既存メモを更新 (upsert / 1 user 1 trip 1 memo)" do
    login_via_api(users(:bob))
    Memo.create!(user: users(:bob), trip: trips(:alice_kyoto), body: "旧メモ")
    assert_no_difference -> { Memo.count } do
      put "/api/v1/trips/#{trips(:alice_kyoto).id}/memo",
        params: { body: "新メモ" }, as: :json
    end
    assert_equal "新メモ", Memo.find_by(user: users(:bob), trip: trips(:alice_kyoto)).body
  end

  test "PUT body=\"\" は削除と等価" do
    login_via_api(users(:bob))
    Memo.create!(user: users(:bob), trip: trips(:alice_kyoto), body: "メモ")
    assert_difference -> { Memo.count }, -1 do
      put "/api/v1/trips/#{trips(:alice_kyoto).id}/memo",
        params: { body: "" }, as: :json
    end
    assert_nil JSON.parse(response.body)["memo"]
  end

  test "PUT body 空白のみ も削除と等価" do
    login_via_api(users(:bob))
    Memo.create!(user: users(:bob), trip: trips(:alice_kyoto), body: "メモ")
    assert_difference -> { Memo.count }, -1 do
      put "/api/v1/trips/#{trips(:alice_kyoto).id}/memo",
        params: { body: "   " }, as: :json
    end
  end

  test "PUT 2000 文字超は 422" do
    login_via_api(users(:bob))
    put "/api/v1/trips/#{trips(:alice_kyoto).id}/memo",
      params: { body: "あ" * 2001 }, as: :json
    assert_response :unprocessable_entity
  end

  test "DELETE で削除 (冪等)" do
    login_via_api(users(:bob))
    Memo.create!(user: users(:bob), trip: trips(:alice_kyoto), body: "x")
    delete "/api/v1/trips/#{trips(:alice_kyoto).id}/memo"
    assert_response :ok
    refute Memo.exists?(user: users(:bob), trip: trips(:alice_kyoto))
  end

  test "他人の draft trip にメモ → 404" do
    login_via_api(users(:bob))
    put "/api/v1/trips/#{trips(:alice_draft).id}/memo",
      params: { body: "怪しい" }, as: :json
    assert_response :not_found
  end

  test "他人の private trip にメモ → 404" do
    login_via_api(users(:bob))
    put "/api/v1/trips/#{trips(:alice_private).id}/memo",
      params: { body: "怪しい" }, as: :json
    assert_response :not_found
  end

  test "trip 詳細は本人のメモのみ my_memo に返す (他人のメモは漏れない)" do
    Memo.create!(user: users(:alice), trip: trips(:alice_kyoto), body: "alice のメモ")
    Memo.create!(user: users(:bob),   trip: trips(:alice_kyoto), body: "bob のメモ")

    login_via_api(users(:bob))
    get "/api/v1/trips/#{trips(:alice_kyoto).id}"
    body = JSON.parse(response.body)
    assert_equal "bob のメモ", body["my_memo"], "bob には bob のメモのみ見える"
  end

  test "trip 詳細 未ログインは my_memo=null" do
    get "/api/v1/trips/#{trips(:alice_kyoto).id}"
    body = JSON.parse(response.body)
    assert_nil body["my_memo"]
  end
end
