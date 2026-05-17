# F-CLEANUP-01: E2E / perf テストデータの完全削除 (Issue #72)
#
# Rails の `dependent: :destroy` 連鎖を経由してユーザー親レコードを destroy_all し、
# trip / comment / like / follow / notification / 各 trip 子 (12 テーブル) を
# 全て連動削除する。SQL 直接 DELETE では orphan が残るため、本スクリプト経由で統一する。
#
# Usage:
#   CLEANUP_PATTERN='e2e\_%'  bin/rails runner script/cleanup_test_users.rb
#   CLEANUP_PATTERN='perf\_%' bin/rails runner script/cleanup_test_users.rb
#
# LIKE pattern の `_` は wildcard なので literal underscore は `\_` でエスケープ必須。
# 終了コード: 残データ / orphan があれば 1、無ければ 0。

pattern = ENV.fetch("CLEANUP_PATTERN") do
  warn "[cleanup] ERROR: CLEANUP_PATTERN env が未設定です (例: 'e2e\\_%')"
  exit 2
end

before_count = User.where("email LIKE ?", pattern).count
puts "[cleanup] users matching #{pattern.inspect} before: #{before_count}"

if before_count > 0
  destroyed = User.where("email LIKE ?", pattern).destroy_all
  puts "[cleanup] destroyed #{destroyed.size} users (dependent: :destroy 連鎖)"
end

after_count = User.where("email LIKE ?", pattern).count
puts "[cleanup] users matching #{pattern.inspect} after:  #{after_count}"

# orphan 検証: trip.user_id が users に存在しないレコード
orphan_trips = Trip.where.not(user_id: User.select(:id)).count
puts "[cleanup] orphan trips (user_id not in users): #{orphan_trips}"

if after_count > 0 || orphan_trips > 0
  warn "[cleanup] WARNING: residue detected — after_users=#{after_count} orphan_trips=#{orphan_trips}"
  exit 1
end

puts "[cleanup] ✓ complete (deleted=#{before_count}, orphan=0)"
