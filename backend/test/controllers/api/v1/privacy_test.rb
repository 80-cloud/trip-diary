require "test_helper"

# 公開 API の情報漏れを固定する (Issue #107)。
# - 他人のメールアドレスを返さない: ログイン時のエラー汎用化 (E-H1) と応答時間の平準化 (E-H2) は
#   「アドレスが登録済みか」を推測させない対策なので、一覧 API からアドレスが読めると意味がなくなる。
# - 人気タグに、非公開・下書きの旅行を数えない: 本人にしか見えない旅行のタグ名が全員に見えてしまう。
class Api::V1::PrivacyTest < ActionDispatch::IntegrationTest
  setup do
    trips(:alice_kyoto).update!(tag_list: [ "京都" ])
    Follow.create!(follower: users(:bob), followed: users(:alice))
  end

  test "未ログインで取得できる API は email を返さない" do
    [
      "/api/v1/trips",
      "/api/v1/trips/#{trips(:alice_kyoto).id}",
      "/api/v1/tags/#{ERB::Util.url_encode('京都')}",
      "/api/v1/users/#{users(:alice).id}/follows?type=followers"
    ].each do |path|
      get path
      assert_response :ok
      assert_no_email_key JSON.parse(response.body), path
    end
  end

  test "ログイン中でも他人の email は返さず、/me は本人の email を返す" do
    login_via_api(users(:alice))

    post "/api/v1/trips/#{trips(:bob_okinawa).id}/favorite"
    get "/api/v1/favorites"
    assert_response :ok
    assert_no_email_key JSON.parse(response.body), "/api/v1/favorites"

    get "/api/v1/me"
    assert_response :ok
    assert_equal users(:alice).email, JSON.parse(response.body).dig("user", "email")
  end

  test "人気タグは公開済みの旅行だけで数え、非公開・下書きにだけ付いたタグは返さない" do
    trips(:alice_private).update!(tag_list: [ "京都", "秘密タグ" ])
    trips(:alice_draft).update!(tag_list: [ "下書きタグ" ])

    get "/api/v1/tags/popular"
    assert_response :ok
    body = JSON.parse(response.body)
    names = body.map { |t| t["name"] }
    refute_includes names, "秘密タグ"
    refute_includes names, "下書きタグ"
    assert_equal 1, body.find { |t| t["name"] == "京都" }["trips_count"]
  end

  private

  # レスポンスの入れ子をすべてたどり、"email" キーが 1 つも無いことを確かめる。
  def assert_no_email_key(node, path)
    case node
    when Hash
      refute node.key?("email"), "#{path} が email を返している: #{node.inspect.truncate(120)}"
      node.each_value { |v| assert_no_email_key(v, path) }
    when Array
      node.each { |v| assert_no_email_key(v, path) }
    end
  end
end
