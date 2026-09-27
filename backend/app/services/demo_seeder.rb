# F-DEMO-01: 公開デモのデモデータを db/demo/<人物のキー>.yml から作る (docs/公開デモ化計画書.md §6)。
# 何度実行しても件数は増えない。デモユーザーはメールアドレス、旅行は投稿者とタイトル、
# コメントは投稿者・旅行・本文、いいね・お気に入り・フォローは 2 者の組で見分ける。
# 旅行の日付と作成日時は、YAML の started_days_ago / days を使って実行日から逆算する。
class DemoSeeder
  class NotConfirmed < StandardError; end

  # この順に作る (ゲストログインでゲストをフォローするのは、id の小さい先頭 2 名)
  PEOPLE = %w[sakura kenta yui mayumi takuya].freeze
  DATA_DIR = Rails.root.join("db/demo")

  def self.run
    new.run
  end

  # デモユーザーを destroy して (関連データも一緒に消える) から作り直す
  def self.reset!
    seeder = new
    seeder.ensure_confirmed!
    User.demo_users.find_each(&:destroy!)
    seeder.run
  end

  def run
    ensure_confirmed!
    people = PEOPLE.map { |key| YAML.load_file(DATA_DIR.join("#{key}.yml")) }
    ActiveRecord::Base.transaction do
      users = people.to_h { |person| [ person["key"], find_or_create_user(person) ] }
      trips = create_trips(people, users)
      people.each { |person| create_reactions(person, users, trips) }
    end
  end

  def ensure_confirmed!
    return unless Rails.env.production?
    return if ENV["DEMO_SEED_CONFIRM"] == "1"

    raise NotConfirmed, "本番でデモデータを作るには DEMO_SEED_CONFIRM=1 を付けてください"
  end

  private

  def find_or_create_user(person)
    User.find_or_create_by!(email: "#{person["key"]}@#{User::DEMO_EMAIL_DOMAIN}") do |user|
      user.display_name = person["display_name"]
      user.bio = person["bio"]
      user.password = SecureRandom.hex(24) # 誰もログインできないよう、作って捨てる
    end
  end

  # 古い旅行から作り、id の順と作成日時の順をそろえる
  def create_trips(people, users)
    rows = people.flat_map { |person| person["trips"].map { |attrs| [ person["key"], attrs ] } }
    rows.sort_by { |_key, attrs| -attrs["started_days_ago"] }.to_h do |key, attrs|
      [ "#{key}/#{attrs["key"]}", find_or_create_trip(users.fetch(key), key, attrs) ]
    end
  end

  def find_or_create_trip(user, user_key, attrs)
    user.trips.find_or_create_by!(title: attrs["title"]) do |trip|
      started_on = Date.current - attrs["started_days_ago"]
      ended_on = started_on + (attrs["days"] - 1)
      posted_at = [ (ended_on + 1).in_time_zone.change(hour: 20), Time.current ].min # 旅行の翌日の夜に投稿した想定
      trip.assign_attributes(
        destination: attrs["destination"], category: attrs["category"],
        visibility: attrs["visibility"], status: attrs.fetch("status", "published"),
        started_on: started_on, ended_on: ended_on, body: attrs["body"], tag_list: attrs["tags"],
        created_at: posted_at, updated_at: posted_at
      )
      build_day_entries(trip, attrs, started_on)
      trip.build_review(rating: attrs["review"]["rating"], body: attrs["review"]["body"]) if attrs["review"]
      attach_image(trip, "#{user_key}_#{attrs["key"]}")
    end
  end

  # 日ごとの記録を旅行の日数に割り振る (記録の数が日数より多い日帰り旅行も同じ日にまとめる)
  def build_day_entries(trip, attrs, started_on)
    entries = attrs["day_entries"]
    entries.each_with_index do |entry, index|
      day = index * attrs["days"] / entries.size
      trip.day_entries.build(
        day_number: day + 1, position: index, happened_on: started_on + day,
        title: entry["title"], body: entry["body"]
      )
    end
  end

  def attach_image(trip, name)
    path = DATA_DIR.join("images", "#{name}.jpg")
    return unless path.exist?

    trip.images.attach(io: path.open, filename: "#{name}.jpg", content_type: "image/jpeg")
  end

  def create_reactions(person, users, trips)
    user = users.fetch(person["key"])
    person["comments"].each do |comment|
      trip = trips.fetch(comment["trip"])
      user.comments.find_or_create_by!(trip: trip, body: comment["body"]) do |record|
        record.created_at = [ trip.created_at + (trip.comments.count + 1).hours, Time.current ].min
      end
    end
    person["likes"].each { |ref| user.likes.find_or_create_by!(trip: trips.fetch(ref)) }
    person["favorites"].each { |ref| user.favorites.find_or_create_by!(trip: trips.fetch(ref)) }
    person["follows"].each { |key| user.active_follows.find_or_create_by!(followed: users.fetch(key)) }
  end
end
