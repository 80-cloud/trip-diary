class CreateMemos < ActiveRecord::Migration[8.1]
  def change
    create_table :memos do |t|
      t.references :user, null: false, foreign_key: true
      t.references :trip, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end
    # 1 user / 1 trip / 1 memo (本人専用なので個数は無関係 = 1 個で十分)
    add_index :memos, [:user_id, :trip_id], unique: true
  end
end
