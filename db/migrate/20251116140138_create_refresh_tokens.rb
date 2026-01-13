class CreateRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :refresh_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :device_info
      t.string :token_ip
      t.datetime :expires_at, null: false
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :refresh_tokens, :token, unique: true
    add_index :refresh_tokens, :expires_at
  end
end
