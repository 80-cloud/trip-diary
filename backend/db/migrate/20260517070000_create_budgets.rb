class CreateBudgets < ActiveRecord::Migration[8.1]
  def change
    create_table :budgets do |t|
      # PR #28 教訓: t.references の auto-index と add_index unique: の衝突を避け
      # index: { unique: true } を一発指定 (1 trip 1 budget を DB で保証)
      t.references :trip, null: false, foreign_key: true, index: { unique: true }
      t.decimal :planned_amount, precision: 10, scale: 2, null: false, default: 0
      t.string :currency, null: false, limit: 3, default: "JPY"

      t.timestamps
    end
  end
end
