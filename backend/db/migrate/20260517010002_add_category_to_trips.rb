class AddCategoryToTrips < ActiveRecord::Migration[8.1]
  def up
    # 一旦 default 付きで追加し既存行を埋める。最後に default を外して
    # 「未選択は明示的にバリデーションエラー」になるようにする。
    # (default を残すと params 省略時に DB が黙って 'domestic' を入れ、
    #  「カテゴリは必須」のモデル検証が発火しなくなる)
    add_column :trips, :category, :string, limit: 32, default: "domestic", null: false
    change_column_default :trips, :category, from: "domestic", to: nil
    add_index :trips, :category
  end

  def down
    remove_index :trips, :category
    remove_column :trips, :category
  end
end
