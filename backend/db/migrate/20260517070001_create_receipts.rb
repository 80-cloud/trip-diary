class CreateReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :receipts do |t|
      t.references :trip, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :category, null: false, limit: 16
      t.string :description, limit: 200
      t.date :spent_on

      t.timestamps
    end
    add_index :receipts, [:trip_id, :spent_on]
    add_index :receipts, [:trip_id, :category]
  end
end
