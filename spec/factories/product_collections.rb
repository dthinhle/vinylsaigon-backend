# == Schema Information
#
# Table name: product_collections
#
#  id          :bigint           not null, primary key
#  active      :boolean          default(TRUE), not null
#  deleted_at  :datetime
#  description :string(80)
#  name        :string           not null
#  slug        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_product_collections_on_deleted_at  (deleted_at)
#  index_product_collections_on_name        (name) UNIQUE
#  index_product_collections_on_slug        (slug) UNIQUE
#
FactoryBot.define do
  factory :product_collection do
    sequence(:name) { |n| "Collection #{n}" }
    sequence(:slug) { |n| "collection-#{n}" }
    description { Faker::Lorem.paragraph }
    active { true }
  end
end
