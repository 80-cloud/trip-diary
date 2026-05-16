class CreateLikes < ActiveRecord::Migration[8.1]
  def change
    create_table :likes do |t|
      t.references :trip, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :likes, [:trip_id, :user_id], unique: true
  end
end
