class CreateRevokedJtis < ActiveRecord::Migration[8.1]
  def change
    create_table :revoked_jtis, id: false do |t|
      # jti は UUID v4 (36 文字)。PK にして O(1) lookup
      t.string :jti, limit: 36, null: false, primary_key: true
      # 元 token の exp を保存。expires_at < now なら lazy cleanup の対象
      t.datetime :expires_at, null: false
      t.datetime :created_at, null: false
    end
    # cleanup の高速化 (expires_at < now の一括 delete に使う)
    add_index :revoked_jtis, :expires_at
  end
end
