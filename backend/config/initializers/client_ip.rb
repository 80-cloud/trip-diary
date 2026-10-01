# P0-10 / Issue #158: 回数制限などで使う訪問者の IP (req.ip) を、公開環境の中継の後ろでも正しく決める。
# 公開環境 (Render) の X-Forwarded-For は「訪問者が送った値, 本当の訪問者, Cloudflare, Render 内部」の並び。
# Rack の req.ip は末尾から見て「信頼する中継」でない最初の IP を選ぶので、Cloudflare の範囲を信頼する中継に足す。
# 訪問者が送った値は本当の訪問者より左にしか来ないため、偽っても選ばれない。
module CloudflareIps
  # 出典: https://www.cloudflare.com/ips-v4 と https://www.cloudflare.com/ips-v6 (2026-10-01 取得)。
  # CI からネットワークを読まないよう、ここに持つ。範囲が変わったら書き直す。
  RANGES = %w[
    173.245.48.0/20
    103.21.244.0/22
    103.22.200.0/22
    103.31.4.0/22
    141.101.64.0/18
    108.162.192.0/18
    190.93.240.0/20
    188.114.96.0/20
    197.234.240.0/22
    198.41.128.0/17
    162.158.0.0/15
    104.16.0.0/13
    104.24.0.0/14
    172.64.0.0/13
    131.0.72.0/22
    2400:cb00::/32
    2606:4700::/32
    2803:f800::/32
    2405:b500::/32
    2405:8100::/32
    2a06:98c0::/29
    2c0f:f248::/32
  ].map { |range| IPAddr.new(range) }.freeze

  def self.include?(ip)
    address = IPAddr.new(ip)
    RANGES.any? { |range| range.include?(address) }
  rescue IPAddr::Error
    false
  end
end

default_ip_filter = Rack::Request.ip_filter
Rack::Request.ip_filter = ->(ip) { default_ip_filter.call(ip) || CloudflareIps.include?(ip) }

# Rack は既定で X-Forwarded-For より先に Forwarded ヘッダーを読む。中継が Forwarded を足さないと、
# 訪問者が送った Forwarded がそのまま使われ、偽って制限をすり抜けられる。X-Forwarded-For だけを読む。
Rack::Request.forwarded_priority = [ :x_forwarded ]
