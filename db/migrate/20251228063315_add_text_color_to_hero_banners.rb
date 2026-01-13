class AddTextColorToHeroBanners < ActiveRecord::Migration[8.1]
  def change
    add_column :hero_banners, :text_color, :string
  end
end
