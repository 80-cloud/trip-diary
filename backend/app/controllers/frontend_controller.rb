# 公開環境で、ビルド済みの画面のひな形 (index.html) を返す (Issue #145)。
# 画面の URL を直接開いたときや再読み込みしたときに使う。画面の切り替えはブラウザ側で行う。
class FrontendController < ApplicationController
  # routes.rb の制約。/api と /rails (画像の配信) と、拡張子の付いたファイルの URL は受け持たない。
  def self.matches?(request)
    return false if request.path.start_with?("/api/", "/rails/")

    File.extname(request.path).empty?
  end

  def show
    path = Rails.configuration.x.frontend_index
    return head :not_found unless File.file?(path)

    response.headers["Cache-Control"] = "no-cache"
    send_file path, type: "text/html; charset=utf-8", disposition: "inline"
  end
end
