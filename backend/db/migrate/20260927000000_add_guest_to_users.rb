# F-GUEST-01: 訪問者ごとの一時ゲスト (Issue #109)
class AddGuestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :guest, :boolean, null: false, default: false
    # 有効なゲスト / 期限切れのゲストを探すための複合 index
    add_index :users, [ :guest, :created_at ]
  end
end
