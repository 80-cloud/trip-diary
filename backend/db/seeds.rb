return unless Rails.env.development?

puts "Seeding users..."
taro   = User.find_or_create_by!(email: "taro@example.com")   { |u| u.password = "password"; u.display_name = "山田太郎"; u.bio = "国内旅行が好きです" }
hanako = User.find_or_create_by!(email: "hanako@example.com") { |u| u.password = "password"; u.display_name = "佐藤花子"; u.bio = "ヨーロッパ周遊に憧れ中" }
jiro   = User.find_or_create_by!(email: "jiro@example.com")   { |u| u.password = "password"; u.display_name = "鈴木次郎"; u.bio = "ひとり旅 / カメラ" }

if Trip.count == 0
  puts "Seeding trips..."

  trip1 = taro.trips.create!(
    title: "京都3日間の旅",
    destination: "京都",
    started_on: Date.new(2026, 4, 1),
    ended_on:   Date.new(2026, 4, 3),
    body: "桜の季節に京都へ。清水寺・嵐山・伏見稲荷を巡る定番ルート。",
    visibility: "public"
  )
  trip1.day_entries.create!(day_number: 1, happened_on: Date.new(2026,4,1), title: "清水寺と東山散策", body: "清水の舞台から市内を一望。昼は湯豆腐。", position: 0)
  trip1.day_entries.create!(day_number: 2, happened_on: Date.new(2026,4,2), title: "嵐山 渡月橋と竹林", body: "桜と竹林のコントラストが美しい。", position: 1)
  trip1.day_entries.create!(day_number: 3, happened_on: Date.new(2026,4,3), title: "伏見稲荷の千本鳥居", body: "早朝に行くと人が少なくて良い。", position: 2)

  trip2 = hanako.trips.create!(
    title: "ハワイ・オアフ島ひとり旅",
    destination: "ハワイ・オアフ島",
    started_on: Date.new(2026, 3, 10),
    ended_on:   Date.new(2026, 3, 15),
    body: "ワイキキ・ノースショア・ダイヤモンドヘッド。海とパンケーキ。",
    visibility: "public"
  )
  trip2.day_entries.create!(day_number: 1, happened_on: Date.new(2026,3,10), title: "ワイキキビーチ", body: "夕日が綺麗。", position: 0)
  trip2.day_entries.create!(day_number: 3, happened_on: Date.new(2026,3,12), title: "ノースショアのエビトラック", body: "Giovanni's の garlic shrimp は名物。", position: 1)

  trip3 = jiro.trips.create!(
    title: "北海道 雪まつり弾丸",
    destination: "札幌",
    started_on: Date.new(2026, 2, 6),
    ended_on:   Date.new(2026, 2, 8),
    body: "2泊3日で雪まつりとスープカレー。",
    visibility: "public"
  )
  trip3.day_entries.create!(day_number: 1, happened_on: Date.new(2026,2,6), title: "大通公園 雪像", body: "夜のライトアップが圧巻。", position: 0)
  trip3.day_entries.create!(day_number: 2, happened_on: Date.new(2026,2,7), title: "藻岩山 夜景", body: "ロープウェイで山頂へ。", position: 1)

  trip1.comments.create!(user: hanako, body: "京都いいですね！来月行く予定です")
  trip1.comments.create!(user: jiro,   body: "嵐山の竹林、写真上手ですね")
  trip2.comments.create!(user: taro,   body: "Giovanni's 美味しそう…！")
  trip3.comments.create!(user: hanako, body: "雪まつり一度行ってみたい")

  trip1.likes.create!(user: hanako)
  trip1.likes.create!(user: jiro)
  trip2.likes.create!(user: taro)
  trip2.likes.create!(user: jiro)
  trip3.likes.create!(user: taro)
end

puts "Done. Users: #{User.count}, Trips: #{Trip.count}, DayEntries: #{DayEntry.count}, Comments: #{Comment.count}, Likes: #{Like.count}"
