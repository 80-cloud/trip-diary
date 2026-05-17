class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets do |t|
      t.references :trip, null: false, foreign_key: true
      # 種別 (新幹線/宿/航空券/各種チケット/その他)
      t.string :kind, null: false, limit: 16
      t.string :reservation_no, limit: 80
      t.string :url, limit: 500
      t.string :notes, limit: 500
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :tickets, [ :trip_id, :position ]
  end
end
