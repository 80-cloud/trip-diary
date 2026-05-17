require "test_helper"

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  # E-H1 回帰 (docs/セキュリティ自己監査.md §3): signup 失敗のレスポンスボディが
  # 失敗原因 (email 重複 / password 短すぎ) で異なってはいけない。
  test "signup error body is identical for email duplication and password too short" do
    # 既存ユーザー (fixture: alice) の email で signup → email 重複エラー
    post "/api/v1/signup",
      params: { email: users(:alice).email, password: "password123", display_name: "Dup" },
      as: :json
    body_dup = response.body
    status_dup = response.status

    # 新規 email + 短すぎる password (5 文字) → password length エラー
    post "/api/v1/signup",
      params: { email: "brand-new@example.com", password: "x", display_name: "Short" },
      as: :json
    body_short = response.body
    status_short = response.status

    assert_equal status_dup, status_short,
      "signup error status must not differ between failure reasons"
    assert_equal body_dup, body_short,
      "signup error body must not differ between duplicate-email and short-password (E-H1)"
    refute_match(/Email/i, body_dup, "field name 'Email' must not leak in error body (E-H1)")
    refute_match(/Password/i, body_dup, "field name 'Password' must not leak in error body (E-H1)")
  end

  # E-H2 回帰 (docs/セキュリティ自己監査.md §3): 不在 email と存在 email (誤 password) の
  # ログイン応答時間差が小さいこと。
  # 注意点:
  #   - 初回 bcrypt 呼び出しはコールドスタートで遅いため warm-up を入れる
  #   - 順序効果を打ち消すため unknown / known を **交互に測定** (interleave)
  test "login response time does not differ significantly for unknown vs known email" do
    samples = 8

    # warm-up: bcrypt / autoloader / DB プールの初回コストを除外
    2.times do
      post "/api/v1/login",
        params: { email: "warmup-#{rand(10_000)}@example.com", password: "x" },
        as: :json
      post "/api/v1/login",
        params: { email: users(:alice).email, password: "warmup-wrong" },
        as: :json
    end

    unknown_times = []
    known_times = []
    samples.times do
      # interleave (順序効果打ち消し)
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      post "/api/v1/login",
        params: { email: "no-such-user-#{rand(10_000)}@example.com", password: "whatever" },
        as: :json
      unknown_times << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t)

      t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      post "/api/v1/login",
        params: { email: users(:alice).email, password: "wrong-password" },
        as: :json
      known_times << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t)
    end

    avg_unknown = unknown_times.sum / samples
    avg_known = known_times.sum / samples
    diff = (avg_unknown - avg_known).abs

    # 許容差 100ms (test 環境 BCrypt cost: 4 では 1 回 bcrypt = 数 ms オーダー)
    assert diff < 0.1,
      "login timing diff too large: unknown=#{avg_unknown.round(4)}s known=#{avg_known.round(4)}s diff=#{diff.round(4)}s (E-H2)"
  end

  test "login with correct credentials returns 200 and sets cookie" do
    post "/api/v1/login",
      params: { email: users(:alice).email, password: "password123" },
      as: :json
    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal users(:alice).email, json.dig("user", "email")
    assert cookies[ApplicationController::COOKIE_NAME.to_s].present?,
      "JWT cookie must be set on successful login"
  end

  # E-L5: Rails-level uniqueness を通過した後の DB race (RecordNotUnique) を 422 で受ける
  # (rescue が無いと 500 になり、攻撃者から「email 既存」と推測されてしまう)
  test "signup: DB unique race は 422 + 汎用メッセージ (500 を出さない)" do
    # 一時的に User#save を RecordNotUnique を上げるように差し替えて controller の
    # rescue 経路を強制的に通す。HTTP 経由で同時 2 リクエストの race を再現するのは
    # 困難なため alias_method による in-place stub を採用。
    User.class_eval do
      alias_method :_real_save, :save
      define_method(:save) { raise ActiveRecord::RecordNotUnique, "Duplicate entry" }
    end
    begin
      post "/api/v1/signup",
        params: { email: "race@example.com", password: "password123", display_name: "R" },
        as: :json
      assert_response :unprocessable_entity
      assert_match(/入力内容に誤りがあります/, JSON.parse(response.body)["error"],
        "DB race でも E-H1 と同じ汎用メッセージで返すこと (email 列挙防止)")
    ensure
      # 他テストに影響しないよう必ず元に戻す
      User.class_eval do
        remove_method :save
        alias_method  :save, :_real_save
        remove_method :_real_save
      end
    end
  end

  # E-M1: rack-attack throttle が login に効く (5 req/min 超過で 429)
  test "login: 6 連射目で 429 (rack-attack)" do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
    begin
      5.times do
        post "/api/v1/login",
          params: { email: "rate-test@example.com", password: "x" },
          as: :json
        assert_includes [401, 422], response.status,
          "1〜5 回目はレート未超過 (#{response.status})"
      end
      post "/api/v1/login",
        params: { email: "rate-test@example.com", password: "x" },
        as: :json
      assert_response :too_many_requests
      body = JSON.parse(response.body)
      assert_match(/リクエストが多すぎます/, body["error"])
    ensure
      Rack::Attack.enabled = false
      Rack::Attack.cache.store.clear
    end
  end

  # E-M1: signup throttle (3 req/min 超過で 429)
  test "signup: 4 連射目で 429 (rack-attack)" do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
    begin
      3.times do |i|
        post "/api/v1/signup",
          params: { email: "rate-sig-#{i}@example.com", password: "password123", display_name: "X" },
          as: :json
        # 成功 (201) か失敗 (422) かは値次第。429 だけ出ないことを確認
        refute_equal 429, response.status, "1〜3 回目は throttle 未発火"
      end
      post "/api/v1/signup",
        params: { email: "rate-sig-final@example.com", password: "password123", display_name: "X" },
        as: :json
      assert_response :too_many_requests
    ensure
      Rack::Attack.enabled = false
      Rack::Attack.cache.store.clear
    end
  end
end
