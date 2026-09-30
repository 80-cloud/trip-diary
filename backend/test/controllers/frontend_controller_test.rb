require "test_helper"
require "tmpdir"

# 公開環境では、Rails がビルド済みの画面も配る (Issue #145)。
# 画面の URL には画面のひな形を返し、API・画像の配信・ヘルスチェックは横取りしない。
class FrontendControllerTest < ActionDispatch::IntegrationTest
  MARK = "trip-diary-shell".freeze

  setup do
    @dir = Dir.mktmpdir
    @original = Rails.configuration.x.frontend_index
    Rails.configuration.x.frontend_index = File.join(@dir, "index.html")
    File.write(Rails.configuration.x.frontend_index, "<html>#{MARK}</html>")
  end

  teardown do
    Rails.configuration.x.frontend_index = @original
    FileUtils.remove_entry(@dir)
  end

  test "画面の URL を直接開くと、キャッシュさせない画面のひな形を返す" do
    %w[/ /login /trips/1 /trips/1/edit /users/1].each do |path|
      get path
      assert_response :ok, path
      assert_equal "text/html", response.media_type, path
      assert_includes response.body, MARK, path
      assert_equal "no-cache", response.headers["Cache-Control"], path
    end
  end

  test "存在しない API の URL は、画面ではなく 404 を返す" do
    get "/api/v1/no_such_endpoint"
    assert_response :not_found
    assert_not_includes response.body, MARK
  end

  test "ヘルスチェックは横取りしない" do
    get "/up"
    assert_response :ok
    assert_not_includes response.body, MARK

    get "/api/v1/health"
    assert_response :ok
    assert_equal "ok", response.parsed_body["status"]
  end

  test "画像の配信の URL は横取りしない" do
    get "/rails/active_storage/blobs/redirect/invalid/photo"
    assert_not_includes response.body, MARK
  end

  test "拡張子の付いた URL は、ファイルが無ければ 404 を返す" do
    get "/_nuxt/missing.js"
    assert_response :not_found
    assert_not_includes response.body, MARK
  end

  test "ひな形のファイルが無いときは 404 を返す (手元の開発では Nuxt が画面を配る)" do
    Rails.configuration.x.frontend_index = File.join(@dir, "missing.html")
    get "/trips/1"
    assert_response :not_found
  end

  test "ひな形の置き場の既定は public の外 (public のファイルは 1 年キャッシュされるため)" do
    assert_equal Rails.root.join("frontend_shell/index.html"), @original
    assert_not @original.to_s.start_with?(Rails.public_path.to_s)
  end
end
