class CreateStores < ActiveRecord::Migration[8.0]
  def change
    create_table :stores do |t|
      t.string :name
      t.string :facebook_url
      t.string :youtube_url
      t.string :instagram_url
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
