class CreatePackingItems < ActiveRecord::Migration[8.1]
  def change
    create_table :packing_items do |t|
      t.references :trip, null: false, foreign_key: true
      t.string :body, null: false, limit: 80
      t.boolean :packed, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :packing_items, [:trip_id, :position]
  end
end
