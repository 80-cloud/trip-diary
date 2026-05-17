class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false, limit: 32
      t.integer :trips_count, null: false, default: 0

      t.timestamps
    end
    add_index :tags, :name, unique: true
    add_index :tags, :trips_count
  end
end
