class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      # t.references の auto-index と add_index unique:true が衝突するため
      # index: { unique: true } を一発で指定する (1 trip / 1 review を DB で保証)
      t.references :trip, null: false, foreign_key: true, index: { unique: true }
      t.integer :rating, null: false
      t.text :body

      t.timestamps
    end
  end
end
