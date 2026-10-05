require "test_helper"

# タブのアイコンと、URL を貼ったときのプレビューの画像は、backend/public から Rails が配る (Issue #169)。
# 公開環境のイメージは、画面のビルドから _nuxt と index.html しかコピーしないため。
class PublicFilesTest < ActionDispatch::IntegrationTest
  test "favicon を返す" do
    get "/favicon.ico"
    assert_response :ok
  end

  test "OGP の画像を PNG で返す" do
    get "/og.png"
    assert_response :ok
    assert_equal "image/png", response.media_type
  end
end
