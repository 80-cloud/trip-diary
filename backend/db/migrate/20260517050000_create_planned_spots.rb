class CreatePlannedSpots < ActiveRecord::Migration[8.1]
  def change
    create_table :planned_spots do |t|
      t.references :trip, null: false, foreign_key: true
      t.string :title, null: false, limit: 80
      t.boolean :done, null: false, default: false
      t.integer :position, null: false, default: 0
      # F-PLAN-02 で done → DayEntry 昇格時に紐付ける。nullable (まだ昇格していない / done=false)。
      t.references :day_entry, null: true, foreign_key: true

      t.timestamps
    end
    add_index :planned_spots, [ :trip_id, :position ]
  end
end
