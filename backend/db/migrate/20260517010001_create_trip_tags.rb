class CreateTripTags < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_tags do |t|
      t.references :trip, null: false, foreign_key: true
      t.references :tag,  null: false, foreign_key: true

      t.timestamps
    end
    add_index :trip_tags, [:trip_id, :tag_id], unique: true
  end
end
