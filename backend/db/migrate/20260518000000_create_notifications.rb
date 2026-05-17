class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      # 受信者 (通知が届くユーザー)
      t.bigint :recipient_id, null: false
      # 行動者 (通知の引き金になったユーザー)
      t.bigint :actor_id, null: false
      # 通知種別: commented / liked / followed
      t.string :verb, limit: 16, null: false
      # polymorphic target (Comment / Like / Follow)
      t.string :target_type, limit: 32, null: false
      t.bigint :target_id, null: false
      # null = 未読
      t.datetime :read_at

      t.timestamps
    end

    add_foreign_key :notifications, :users, column: :recipient_id, on_delete: :cascade
    add_foreign_key :notifications, :users, column: :actor_id,     on_delete: :cascade

    # 未読絞り込み (ER 図 §5-3 準拠)
    add_index :notifications, [:recipient_id, :read_at]
    # 一覧の時系列ソート
    add_index :notifications, [:recipient_id, :created_at]
    # polymorphic 既定
    add_index :notifications, [:target_type, :target_id]
  end
end
