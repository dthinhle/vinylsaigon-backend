class CreateHeroBanners < ActiveRecord::Migration[8.0]
  def change
    create_table :hero_banners do |t|
      t.string :main_title
      t.string :sub_title
      t.text :description
      t.string :short_description, limit: 500
      t.string :url
      t.datetime :deleted_at, index: true

      t.timestamps
    end
  end
end
