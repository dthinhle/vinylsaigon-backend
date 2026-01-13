# == Schema Information
#
# Table name: brands
#
#  id         :bigint           not null, primary key
#  deleted_at :datetime
#  name       :string           not null
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_brands_on_deleted_at  (deleted_at)
#  index_brands_on_name        (name) UNIQUE
#  index_brands_on_slug        (slug) UNIQUE
#
FactoryBot.define do
  factory :brand do
    sequence(:name) { |n| "Brand #{n}" }
    sequence(:slug) { |n| "brand-#{n}" }

    trait :with_logo do
      after(:create) do |brand|
        brand.logo.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.jpg')),
          filename: 'logo.jpg',
          content_type: 'image/jpeg'
        )
      end
    end

    trait :with_banner do
      after(:create) do |brand|
        brand.banner.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.jpg')),
          filename: 'banner.jpg',
          content_type: 'image/jpeg'
        )
      end
    end
  end
end
