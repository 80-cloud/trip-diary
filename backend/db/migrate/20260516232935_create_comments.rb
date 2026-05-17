class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :trip, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: true
      t.string :body, null: false, limit: 140

      t.timestamps
    end
    add_index :comments, [ :trip_id, :created_at ]
  end
end
