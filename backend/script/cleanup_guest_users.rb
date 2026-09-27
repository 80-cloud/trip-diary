# F-GUEST-01: 期限切れゲストの手動削除 (Issue #109)
#
# ゲストログインのたびに期限切れのゲストを最大 20 人ずつ削除しているが、訪問が途絶えると
# 残り続ける。まとめて片付けるときに使う。User.cleanup_expired_guests! (destroy 経由) を
# 繰り返すので、関連データも `dependent: :destroy` で一緒に削除される。
#
# Usage:
#   bin/rails runner script/cleanup_guest_users.rb
#
# 終了コード: 期限切れゲスト / orphan が残れば 1、無ければ 0。

before_count = User.expired_guests.count
puts "[cleanup] expired guests before: #{before_count}"

destroyed = 0
loop do
  count = User.cleanup_expired_guests!
  break if count.zero?

  destroyed += count
end
puts "[cleanup] destroyed #{destroyed} guests (dependent: :destroy 連鎖)"

after_count = User.expired_guests.count
puts "[cleanup] expired guests after:  #{after_count}"

# orphan 検証: user_id が users に存在しないレコード
user_ids = User.select(:id)
orphans = {
  trips: Trip.where.not(user_id: user_ids).count,
  comments: Comment.where.not(user_id: user_ids).count,
  follows: Follow.where.not(follower_id: user_ids).or(Follow.where.not(followed_id: user_ids)).count,
  notifications: Notification.where.not(recipient_id: user_ids).or(Notification.where.not(actor_id: user_ids)).count
}
puts "[cleanup] orphans: #{orphans}"

if after_count > 0 || orphans.values.any?(&:positive?)
  warn "[cleanup] WARNING: residue detected — after_guests=#{after_count} orphans=#{orphans}"
  exit 1
end

puts "[cleanup] ✓ complete (deleted=#{destroyed}, orphan=0)"
