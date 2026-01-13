# == Schema Information
#
# Table name: products
#
#  id                   :bigint           not null, primary key
#  deleted_at           :datetime
#  description          :jsonb            not null
#  featured             :boolean          default(FALSE), not null
#  flags                :string           default([]), is an Array
#  free_installment_fee :boolean          default(TRUE), not null
#  gift_content         :jsonb            not null
#  legacy_attributes    :jsonb
#  low_stock_threshold  :integer          default(5), not null
#  meta_description     :string(500)
#  meta_title           :string(255)
#  name                 :string           not null
#  price_updated_at     :datetime
#  product_attributes   :jsonb
#  product_tags         :string           default([]), is an Array
#  short_description    :jsonb            not null
#  sku                  :string           not null
#  slug                 :string
#  sort_order           :integer          default(0), not null
#  status               :string           default("inactive"), not null
#  stock_quantity       :integer          default(0), not null
#  stock_status         :string           default("in_stock"), not null
#  warranty_months      :integer
#  weight               :decimal(8, 2)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  category_id          :bigint
#  legacy_wp_id         :integer
#
# Indexes
#
#  index_products_on_category_id  (category_id)
#  index_products_on_deleted_at   (deleted_at)
#  index_products_on_sku          (sku) UNIQUE
#  index_products_on_slug         (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#
FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    sequence(:sku) { |n| "SKU-#{n}" }
    sequence(:slug) { |n| "product-#{n}" }
    description do
      {
        root: {
          type: 'root',
          children: [
            {
              type: 'paragraph',
              children: [
                {
                  type: 'text',
                  text: Faker::Lorem.paragraph
                },
              ]
            },
          ]
        }
      }
    end
    short_description do
      {
        root: {
          type: 'root',
          children: [
            {
              type: 'paragraph',
              children: [
                {
                  type: 'text',
                  text: Faker::Lorem.sentence
                },
              ]
            },
          ]
        }
      }
    end
    status { 'active' }
    stock_status { 'in_stock' }
    stock_quantity { 100 }
    low_stock_threshold { 5 }
    featured { false }
    flags { [] }
    sort_order { 0 }
    meta_title { Faker::Lorem.sentence }
    meta_description { Faker::Lorem.sentence }
    category { nil }

    trait :with_category do
      category { association :category }
    end

    trait :inactive do
      status { 'inactive' }
    end

    trait :discontinued do
      status { 'discontinued' }
    end

    trait :out_of_stock do
      stock_status { 'out_of_stock' }
      stock_quantity { 0 }
    end

    trait :low_stock do
      stock_status { 'low_stock' }
      stock_quantity { 3 }
    end

    trait :featured do
      featured { true }
    end

    trait :with_flags do
      flags { ['just arrived'] }
    end

    trait :with_gift do
      gift_content { Faker::Lorem.paragraph }
    end

    trait :with_brands do
      after(:create) do |product|
        product.brands << create_list(:brand, 2)
      end
    end

    trait :with_collections do
      after(:create) do |product|
        product.product_collections << create_list(:product_collection, 2)
      end
    end

    trait :with_tags do
      product_tags { ['Tag 1', 'Tag 2', 'Tag 3'] }
    end
  end
end
