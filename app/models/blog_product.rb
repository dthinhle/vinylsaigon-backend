# == Schema Information
#
# Table name: blog_products
#
#  id         :bigint           not null, primary key
#  deleted_at :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  blog_id    :bigint           not null
#  product_id :bigint           not null
#
# Indexes
#
#  index_blog_products_on_blog_id     (blog_id)
#  index_blog_products_on_deleted_at  (deleted_at)
#  index_blog_products_on_product_id  (product_id)
#
# Foreign Keys
#
#  fk_rails_...  (blog_id => blogs.id)
#  fk_rails_...  (product_id => products.id)
#
class BlogProduct < ApplicationRecord
  belongs_to :blog
  belongs_to :product
end
