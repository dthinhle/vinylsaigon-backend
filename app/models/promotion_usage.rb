# == Schema Information
#
# Table name: promotion_usages
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE), not null
#  metadata        :jsonb
#  redeemable_type :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  promotion_id    :bigint           not null
#  redeemable_id   :uuid
#  user_id         :bigint
#
# Indexes
#
#  index_promotion_usages_on_promotion_id                 (promotion_id)
#  index_promotion_usages_on_promotion_id_and_created_at  (promotion_id,created_at)
#  index_promotion_usages_on_promotion_id_and_user_id     (promotion_id,user_id)
#
# Foreign Keys
#
#  fk_rails_...  (promotion_id => promotions.id) ON DELETE => restrict
#
class PromotionUsage < ApplicationRecord
  belongs_to :promotion, counter_cache: :usage_count
  belongs_to :user, optional: true
  belongs_to :redeemable, polymorphic: true

  validates :promotion, presence: true

  scope :active, -> { where(active: true) }
  scope :by_user, ->(u) { where(user_id: u&.id) if u }
end
