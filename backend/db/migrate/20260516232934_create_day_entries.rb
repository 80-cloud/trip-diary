class CreateDayEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :day_entries do |t|
      t.references :trip, null: false, foreign_key: { on_delete: :cascade }
      t.integer :day_number, null: false, default: 1
      t.date :happened_on
      t.string :title, null: false, limit: 80
      t.text :body
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :day_entries, [:trip_id, :position]
  end
end
