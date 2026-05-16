class CreateTrips < ActiveRecord::Migration[8.1]
  def change
    create_table :trips do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false, limit: 80
      t.string :destination, null: false, limit: 80
      t.date :started_on, null: false
      t.date :ended_on, null: false
      t.text :body
      t.string :visibility, null: false, default: "public", limit: 16
      t.integer :likes_count, null: false, default: 0
      t.integer :comments_count, null: false, default: 0

      t.timestamps
    end
    add_index :trips, :created_at
    add_index :trips, :destination
  end
end
