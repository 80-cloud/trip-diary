require "test_helper"

# 公開環境の回数制限は、訪問者ごとの IP で数える (Issue #151 / 公開デモ化計画書 P0-10)。
# Render は X-Forwarded-For の先頭を訪問者の IP にし、その後ろに中継の IP を足す。
# テストでは中継を公開の IP (198.51.100.9) にして、Rack の req.ip が中継を選ぶ状況を作る。
class ClientIpRateLimitTest < ActionDispatch::IntegrationTest
  PROXY = "198.51.100.9".freeze

  setup do
    @original = ENV["TRUST_FIRST_FORWARDED_IP"]
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
  end

  teardown do
    ENV["TRUST_FIRST_FORWARDED_IP"] = @original
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end

  test "先頭を信じる設定では、先頭の IP が違う 6 人がゲストで入れる" do
    ENV["TRUST_FIRST_FORWARDED_IP"] = "1"

    6.times do |i|
      guest_login_from "203.0.113.#{i + 1}, #{PROXY}"
      assert_response :created, "#{i + 1} 人目"
    end
  end

  test "先頭を信じる設定でも、同じ訪問者の 6 回目は 429" do
    ENV["TRUST_FIRST_FORWARDED_IP"] = "1"

    5.times { guest_login_from "203.0.113.1, #{PROXY}" }
    guest_login_from "203.0.113.1, #{PROXY}"
    assert_response :too_many_requests
  end

  test "先頭を信じる設定では、先頭より後ろの IP を変えてもごまかせない" do
    ENV["TRUST_FIRST_FORWARDED_IP"] = "1"

    5.times { |i| guest_login_from "203.0.113.1, 192.0.2.#{i + 1}, #{PROXY}" }
    guest_login_from "203.0.113.1, 192.0.2.99, #{PROXY}"
    assert_response :too_many_requests
  end

  test "先頭を信じる設定でも、先頭が IP の形でなければ req.ip で数える" do
    ENV["TRUST_FIRST_FORWARDED_IP"] = "1"

    5.times { |i| guest_login_from "unknown-#{i}, #{PROXY}" }
    guest_login_from "unknown-9, #{PROXY}"
    assert_response :too_many_requests
  end

  test "設定が無ければ、先頭の IP を変えても今までどおり req.ip で数える" do
    ENV.delete("TRUST_FIRST_FORWARDED_IP")

    5.times { |i| guest_login_from "203.0.113.#{i + 1}, #{PROXY}" }
    guest_login_from "203.0.113.99, #{PROXY}"
    assert_response :too_many_requests
  end

  private

  def guest_login_from(forwarded_for)
    post "/api/v1/guest_login", headers: { "X-Forwarded-For" => forwarded_for }
  end
end
