# == Schema Information
#
# Table name: cart_promotions
#
#  id           :bigint           not null, primary key
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cart_id      :uuid             not null
#  promotion_id :bigint           not null
#
# Indexes
#
#  index_cart_promotions_on_cart_id       (cart_id)
#  index_cart_promotions_on_promotion_id  (promotion_id)
#
# Foreign Keys
#
#  fk_rails_...  (cart_id => carts.id)
#  fk_rails_...  (promotion_id => promotions.id)
#
class CartPromotion < ApplicationRecord
  belongs_to :cart
  belongs_to :promotion
end
