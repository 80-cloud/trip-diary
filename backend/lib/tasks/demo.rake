# F-DEMO-01: 公開デモのデモデータ (docs/公開デモ化計画書.md §6)。
# 本番では DEMO_SEED_CONFIRM=1 を付けたときだけ動く (付けないと DemoSeeder::NotConfirmed で止まる)。
namespace :demo do
  desc "デモデータを作る (何度実行しても件数は増えない)"
  task seed: :environment do
    DemoSeeder.run
    puts "デモデータを作成しました (デモユーザー #{User.demo_users.count} 人)"
  end

  desc "デモユーザーと関連データを消してから、デモデータを作り直す"
  task reset: :environment do
    DemoSeeder.reset!
    puts "デモデータを作り直しました (デモユーザー #{User.demo_users.count} 人)"
  end
end
