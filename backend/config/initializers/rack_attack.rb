# E-M1: ブルートフォース対策 (docs/セキュリティ自己監査.md §2)
# 未認証経路 (login / signup) を IP ベースでスロットル。

class Rack::Attack
  # メモリストア (Rails.cache が memory_store の場合と一致)。
  # 単一インスタンス前提。production で複数インスタンスにする際は Redis backend に切替。
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # POST /api/v1/login: 5 req / 分 / IP
  throttle("login/ip", limit: 5, period: 60.seconds) do |req|
    req.ip if req.post? && req.path == "/api/v1/login"
  end

  # POST /api/v1/signup: 3 req / 分 / IP (作成系はより厳しめ)
  throttle("signup/ip", limit: 3, period: 60.seconds) do |req|
    req.ip if req.post? && req.path == "/api/v1/signup"
  end

  # 429 レスポンス整形 (フィールド名 / 残り時間など機密を漏らさない一般メッセージ)
  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "リクエストが多すぎます。しばらくしてから再試行してください" }.to_json ]
    ]
  end
end

# test 環境では既定で無効化 (E-H2 timing test など 1 test 内で多数 login を発行する
# 既存テストを壊さないため)。レート制限テストは setup/teardown で個別有効化する。
Rack::Attack.enabled = false if Rails.env.test?

# 開発時の perf テスト (k6 VU 5-10 / 要件定義書 §4-1 SLO 検証) で signup/login を
# 短時間に大量発行するため、opt-in env var で disable できるようにする。
# 既定 (env 未設定 / "1" 以外) では throttle 有効を維持する (security default-safe)。
# 使用例: RACK_ATTACK_DISABLED=1 bin/rails s -p 3010
# 本番では絶対に設定しないこと (rack-attack は E-M1 ブルートフォース対策の中核)。
Rack::Attack.enabled = false if ENV["RACK_ATTACK_DISABLED"] == "1"
