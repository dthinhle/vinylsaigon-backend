# == Schema Information
#
# Table name: product_variants
#
#  id                 :bigint           not null, primary key
#  current_price      :decimal(, )
#  deleted_at         :datetime
#  name               :string           not null
#  original_price     :decimal(, )
#  short_description  :string(80)
#  sku                :string           not null
#  slug               :string
#  sort_order         :integer
#  status             :string           default("active"), not null
#  stock_quantity     :integer
#  variant_attributes :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  product_id         :bigint           not null
#
# Indexes
#
#  index_product_variants_on_deleted_at          (deleted_at)
#  index_product_variants_on_product_id          (product_id)
#  index_product_variants_on_product_id_and_sku  (product_id,sku) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#
FactoryBot.define do
  factory :product_variant do
    association :product
    sequence(:name) { |n| "Variant #{n}" }
    sequence(:sku) { |n| "VAR-SKU-#{n}" }
    sequence(:slug) { |n| "variant-#{n}" }
    original_price { 100.00 }
    current_price { 90.00 }
    status { 'active' }
    stock_quantity { 50 }
    sort_order { 0 }

    trait :default_variant do
      name { 'Default' }
      sku { product.sku }
      slug { product.slug }
    end

    trait :inactive do
      status { 'inactive' }
    end

    trait :discontinued do
      status { 'discontinued' }
    end

    trait :no_discount do
      current_price { nil }
    end

    trait :on_sale do
      original_price { 100.00 }
      current_price { 75.00 }
    end

    trait :out_of_stock do
      stock_quantity { 0 }
    end

    trait :with_images do
      after(:create) do |variant|
        3.times do
          variant.images.attach(
            io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.jpg')),
            filename: 'test_image.jpg',
            content_type: 'image/jpeg'
          )
        end
      end
    end

    trait :with_attributes do
      variant_attributes do
        {
          'color' => 'Red',
          'size' => 'Large'
        }
      end
    end
  end
end
