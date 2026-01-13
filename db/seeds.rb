# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# # Ensure an admin user exists with the specified credentials
Admin.find_or_create_by!(email: 'admin@admin.com') do |admin|
  admin.password = '123123'
  admin.password_confirmation = '123123'
  admin.name = 'Admin'
end

require_relative('seeds/meilisearch_data')
require_relative('seeds/hero_banners')

require_relative('seeds/categories')
require_relative('seeds/related_categories')
require_relative('seeds/menu_bar')

require_relative('seeds/product_images')
require_relative('seeds/products')
require_relative('seeds/product_variants')

require_relative('seeds/blogs')
require_relative('seeds/index_product')
require_relative('seeds/store')
require_relative('seeds/promotions')
require_relative('seeds/system_configs')
require_relative('seeds/carts')
require_relative('seeds/users')
require_relative('seeds/orders')
require_relative('seeds/payment_transactions')
