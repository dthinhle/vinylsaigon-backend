# == Schema Information
#
# Table name: categories
#
#  id          :bigint           not null, primary key
#  button_text :string
#  deleted_at  :datetime
#  description :string
#  is_root     :boolean          default(FALSE)
#  slug        :string
#  title       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  parent_id   :bigint
#
# Indexes
#
#  index_categories_on_deleted_at  (deleted_at)
#  index_categories_on_parent_id   (parent_id)
#  index_categories_on_title       (title)
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => categories.id)
#
FactoryBot.define do
  factory :category do
    sequence(:title) { |n| "Category #{n}" }
    sequence(:slug) { |n| "category-#{n}" }
    description { Faker::Lorem.sentence }
    is_root { false }
    button_text { nil }
    parent { nil }

    trait :root do
      is_root { true }
      parent { nil }
    end

    trait :with_parent do
      parent { association :category, :root }
      is_root { false }
    end

    trait :with_image do
      after(:create) do |category|
        category.image.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.jpg')),
          filename: 'test_image.jpg',
          content_type: 'image/jpeg'
        )
      end
    end
  end
end
