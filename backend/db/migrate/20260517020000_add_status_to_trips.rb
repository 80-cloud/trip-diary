class AddStatusToTrips < ActiveRecord::Migration[8.1]
  def up
    # 既存行は "published" として扱う (Phase 1 MVP の全 trip は公開済) ため
    # 一旦 default 付きで追加 → 既存行を埋める → default を外す
    # (default を残すと params 省略時に DB が黙って "published" を入れ、
    #  enum :status のバリデーションが発火しない罠を回避)
    add_column :trips, :status, :string, limit: 16, default: "published", null: false
    change_column_default :trips, :status, from: "published", to: nil
    add_index :trips, :status
  end

  def down
    remove_index :trips, :status
    remove_column :trips, :status
  end
end
