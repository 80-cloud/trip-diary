require "test_helper"
require "rake"

# F-DEMO-01: デモデータ (Issue #117)
# 受け入れ条件は Issue #117 と docs/公開デモ化計画書.md §6-4 に対応する。
# ゲストログインと旅行一覧の API も確かめるため、IntegrationTest にしている。
class DemoSeederTest < ActionDispatch::IntegrationTest
  test "デモユーザー 5 人と旅行 18 件ができ、公開旅行すべてにコメントといいねがあり、写真が 1 枚ずつ付く" do
    DemoSeeder.run

    assert_equal 5, User.demo_users.count
    assert User.demo_users.none?(&:guest?)
    assert_equal 18, demo_trips.count
    public_demo_trips.each do |trip|
      assert trip.comments.exists?, "#{trip.title} にコメントがない"
      assert trip.likes.exists?, "#{trip.title} にいいねがない"
    end
    demo_trips.each { |trip| assert_equal 1, trip.images.count, "#{trip.title} の写真" }
  end

  test "2 回実行してもどの件数も増えない" do
    DemoSeeder.run
    before = record_counts
    DemoSeeder.run
    assert_equal before, record_counts
  end

  test "production で DEMO_SEED_CONFIRM が無ければ中止し、何も作らない" do
    as_production(confirm: nil) do
      assert_no_difference -> { User.count } do
        assert_raises(DemoSeeder::NotConfirmed) { DemoSeeder.run }
      end
    end
  end

  test "production でも DEMO_SEED_CONFIRM=1 なら作る" do
    as_production(confirm: "1") { DemoSeeder.run }
    assert_equal 5, User.demo_users.count
  end

  test "production で DEMO_SEED_CONFIRM が無ければ reset も中止し、デモユーザーを消さない" do
    DemoSeeder.run
    as_production(confirm: nil) do
      assert_no_difference -> { User.demo_users.count } do
        assert_raises(DemoSeeder::NotConfirmed) { DemoSeeder.reset! }
      end
    end
  end

  test "reset はデモユーザーと関連データを消してから作り直し、孤立したレコードが残らない" do
    DemoSeeder.run
    old_ids = User.demo_users.ids
    post "/api/v1/guest_login"
    assert_response :created

    DemoSeeder.reset!

    assert_empty User.where(id: old_ids)
    assert_equal 5, User.demo_users.count
    assert_equal 18, demo_trips.count
    user_ids = User.select(:id)
    trip_ids = Trip.select(:id)
    assert_equal 0, Trip.where.not(user_id: user_ids).count
    assert_equal 0, Comment.where.not(user_id: user_ids).or(Comment.where.not(trip_id: trip_ids)).count
    assert_equal 0, Follow.where.not(follower_id: user_ids).or(Follow.where.not(followed_id: user_ids)).count
    assert_equal 0, Notification.where.not(recipient_id: user_ids).or(Notification.where.not(actor_id: user_ids)).count
  end

  test "8 カテゴリすべてに公開旅行が 1 件以上ある" do
    DemoSeeder.run
    assert_equal Trip.categories.keys.sort, public_demo_trips.distinct.pluck(:category).sort
  end

  test "デモデータのあとでゲストログインすると、未読の通知が 2 件ある" do
    DemoSeeder.run
    post "/api/v1/guest_login"
    assert_response :created

    get "/api/v1/notifications/unread_count"
    assert_equal 2, JSON.parse(response.body)["unread_count"]
  end

  test "旅行の作成日時は直近 3 か月に収まり、一覧を最後までたどっても抜け・重複が無い" do
    DemoSeeder.run
    demo_trips.each do |trip|
      assert_operator trip.created_at, :>, 3.months.ago, trip.title
      assert_operator trip.created_at, :<=, Time.current, trip.title
    end

    ids = []
    cursor = nil
    30.times do
      get "/api/v1/trips", params: { limit: 5, cursor: cursor }.compact
      body = JSON.parse(response.body)
      ids.concat(body["trips"].map { |t| t["id"] })
      cursor = body["next_cursor"]
      break if cursor.nil?
    end
    assert_equal Trip.visible_to(nil).sorted("recent").pluck(:id), ids
  end

  test "rake demo:seed で DemoSeeder が動く" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("demo:seed")
    Rake::Task["demo:seed"].reenable
    capture_io { Rake::Task["demo:seed"].invoke }
    assert_equal 5, User.demo_users.count
  end

  private

  def demo_trips
    Trip.where(user: User.demo_users)
  end

  def public_demo_trips
    demo_trips.where(visibility: "public", status: "published")
  end

  def record_counts
    {
      demo_users: User.demo_users.count, trips: Trip.count, day_entries: DayEntry.count,
      trip_tags: TripTag.count, reviews: Review.count, comments: Comment.count, likes: Like.count,
      follows: Follow.count, favorites: Favorite.count, notifications: Notification.count,
      attachments: ActiveStorage::Attachment.count
    }
  end

  # Rails.env と DEMO_SEED_CONFIRM を一時的に切り替える (minitest 6 には minitest/mock が無い)
  def as_production(confirm:)
    original_env = Rails.env
    original_confirm = ENV["DEMO_SEED_CONFIRM"]
    Rails.env = "production"
    ENV["DEMO_SEED_CONFIRM"] = confirm
    yield
  ensure
    Rails.env = original_env
    ENV["DEMO_SEED_CONFIRM"] = original_confirm
  end
end
