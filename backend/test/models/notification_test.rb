require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @alice = users(:alice)
    @bob   = users(:bob)
    @trip  = trips(:alice_kyoto)
    # target として使う Comment を 1 件用意。Comment#after_commit で
    # Notification も 1 件作られるので、テスト前にリセットする。
    @comment = Comment.create!(trip: @trip, user: @bob, body: "テスト")
    Notification.delete_all
  end

  # ----- 必須 / バリデーション -----

  test "recipient / actor / target / verb 必須" do
    n = Notification.new
    refute n.valid?
    assert_includes n.errors[:recipient], "must exist"
    assert_includes n.errors[:actor], "must exist"
    assert_includes n.errors[:target], "must exist"
    assert_includes n.errors[:verb], "is not included in the list"
  end

  test "verb は VERBS に含まれる値のみ" do
    n = Notification.new(recipient: @alice, actor: @bob, target: @comment, verb: "shouted")
    refute n.valid?
    assert_includes n.errors[:verb], "is not included in the list"
  end

  test "自分自身宛 (actor == recipient) は invalid" do
    n = Notification.new(recipient: @alice, actor: @alice, target: @comment, verb: "commented")
    refute n.valid?
    assert_includes n.errors[:base], "自分自身への通知は作成できません"
  end

  test "同一 (recipient, actor, verb, target) は重複作成不可" do
    Notification.create!(recipient: @alice, actor: @bob, target: @comment, verb: "commented")
    dup = Notification.new(recipient: @alice, actor: @bob, target: @comment, verb: "commented")
    refute dup.valid?
  end

  # ----- scope -----

  test ".unread は read_at が nil のみ返す" do
    unread = Notification.create!(recipient: @alice, actor: @bob, target: @comment, verb: "commented")
    read   = Notification.create!(recipient: @alice, actor: @bob, target: @comment, verb: "liked", read_at: Time.current)
    result = Notification.unread.to_a
    assert_includes result, unread
    refute_includes result, read
  end

  test ".recent は created_at 降順" do
    # uniqueness scope = [actor, verb, target] なので verb を変えて 2 行作成
    older = Notification.create!(recipient: @alice, actor: @bob, target: @comment, verb: "commented", created_at: 2.hours.ago)
    newer = Notification.create!(recipient: @alice, actor: @bob, target: @comment, verb: "liked",     created_at: 1.minute.ago)
    assert_equal [ newer, older ], Notification.recent.to_a
  end

  # ----- read! -----

  test "#read! で read_at がセットされる" do
    n = Notification.create!(recipient: @alice, actor: @bob, target: @comment, verb: "commented")
    assert_nil n.read_at
    n.read!
    assert_not_nil n.reload.read_at
  end

  test "#read! は既読の通知に対しては no-op" do
    t = 1.day.ago
    n = Notification.create!(recipient: @alice, actor: @bob, target: @comment, verb: "commented", read_at: t)
    n.read!
    # 既読時刻が更新されないこと (1 秒未満の誤差は許容)
    assert_in_delta t.to_i, n.reload.read_at.to_i, 1
  end

  # ----- User 関連 -----

  test "User#notifications は recipient = self のみ" do
    mine    = Notification.create!(recipient: @alice, actor: @bob,   target: @comment, verb: "commented")
    others  = Notification.create!(recipient: @bob,   actor: @alice, target: @comment, verb: "liked")
    assert_includes @alice.notifications, mine
    refute_includes @alice.notifications, others
  end
end
