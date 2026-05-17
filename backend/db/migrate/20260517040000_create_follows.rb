class CreateFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :follows do |t|
      # 「フォローする側」
      t.bigint :follower_id, null: false
      # 「フォローされる側」
      t.bigint :followed_id, null: false

      t.timestamps
    end
    add_foreign_key :follows, :users, column: :follower_id
    add_foreign_key :follows, :users, column: :followed_id
    add_index :follows, :follower_id
    add_index :follows, :followed_id
    # 同じ (follower, followed) ペアは 1 件のみ (race 最終防衛)
    add_index :follows, [:follower_id, :followed_id], unique: true
  end
end
