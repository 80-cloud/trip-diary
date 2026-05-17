class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.references :trip, null: false, foreign_key: true

      t.timestamps
    end
    # 1 user / 1 trip / 1 favorite を DB レイヤで強制 (アプリ層 + 並行 race の最終防衛線)
    add_index :favorites, [:user_id, :trip_id], unique: true
    # 一覧の「自分のお気に入り新しい順」を高速化
    add_index :favorites, [:user_id, :created_at]
  end
end
