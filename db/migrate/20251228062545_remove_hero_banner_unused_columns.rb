class RemoveHeroBannerUnusedColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :hero_banners, :sub_title
    remove_column :hero_banners, :short_description
  end
end
