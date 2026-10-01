require "test_helper"

# 公開環境の回数制限は、中継の後ろでも訪問者ごとの IP で数える (Issue #158 / 公開デモ化計画書 P0-10)。
# 公開環境の X-Forwarded-For は「訪問者が送った値, 本当の訪問者, Cloudflare, Render 内部」の並び。
# テストでは、公開環境のログで見た中継の IP を使って同じ並びを作る。
class ClientIpRateLimitTest < ActionDispatch::IntegrationTest
  CLOUDFLARE = "141.101.87.23".freeze
  INTERNAL = "10.25.16.5".freeze
  VISITOR = "198.51.100.20".freeze

  setup do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
  end

  teardown do
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end

  test "偽の X-Forwarded-For を毎回変えても、同じ訪問者の 6 回目は 429" do
    5.times { |i| guest_login_via_proxy "203.0.113.#{i + 1}, #{VISITOR}" }
    assert_response :created

    guest_login_via_proxy "203.0.113.99, #{VISITOR}"
    assert_response :too_many_requests
  end

  test "偽の値に Cloudflare の IP を混ぜても、同じ訪問者の 6 回目は 429" do
    5.times { |i| guest_login_via_proxy "203.0.113.#{i + 1}, 104.16.0.#{i + 1}, #{VISITOR}" }
    assert_response :created

    guest_login_via_proxy "203.0.113.99, 104.16.0.99, #{VISITOR}"
    assert_response :too_many_requests
  end

  test "偽の Forwarded を毎回変えても、同じ訪問者の 6 回目は 429" do
    5.times { |i| guest_login_via_proxy VISITOR, "Forwarded" => "for=203.0.113.#{i + 1}" }
    assert_response :created

    guest_login_via_proxy VISITOR, "Forwarded" => "for=203.0.113.99"
    assert_response :too_many_requests
  end

  test "ちがう訪問者 6 人が同じ Cloudflare の IP を通っても、全員ゲストで入れる" do
    6.times do |i|
      guest_login_via_proxy "198.51.100.#{i + 1}"
      assert_response :created, "#{i + 1} 人目"
    end
  end

  test "X-Forwarded-For が無いときは REMOTE_ADDR で数える" do
    5.times { guest_login_direct "192.0.2.1" }
    guest_login_direct "192.0.2.1"
    assert_response :too_many_requests

    guest_login_direct "192.0.2.2"
    assert_response :created
  end

  test "Cloudflare の範囲に、公開環境のログで見た中継の IP が入る" do
    %w[141.101.87.23 172.68.164.17 172.70.208.16].each do |ip|
      assert CloudflareIps.include?(ip), ip
    end
    assert_not CloudflareIps.include?(VISITOR)
    assert_not CloudflareIps.include?("unknown")
  end

  private

  def guest_login_via_proxy(forwarded_for, extra_headers = {})
    post "/api/v1/guest_login",
      headers: { "X-Forwarded-For" => "#{forwarded_for}, #{CLOUDFLARE}" }.merge(extra_headers),
      env: { "REMOTE_ADDR" => INTERNAL }
  end

  def guest_login_direct(remote_addr)
    post "/api/v1/guest_login", env: { "REMOTE_ADDR" => remote_addr }
  end
end
