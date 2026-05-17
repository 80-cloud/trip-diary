require "test_helper"

class Api::V1::CommentsControllerTest < ActionDispatch::IntegrationTest
  # PR #20 可視性バイパス回帰テスト (likes と同じ系統)
  test "他人の draft trip にコメントできない (404)" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_draft).id}/comments",
      params: { body: "怪しい" }, as: :json
    assert_response :not_found
  end

  test "他人の private trip にコメントできない (404)" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_private).id}/comments",
      params: { body: "怪しい" }, as: :json
    assert_response :not_found
  end

  test "公開 trip にはコメントできる" do
    login_via_api(users(:bob))
    post "/api/v1/trips/#{trips(:alice_kyoto).id}/comments",
      params: { body: "素敵" }, as: :json
    assert_response :created
  end
end
