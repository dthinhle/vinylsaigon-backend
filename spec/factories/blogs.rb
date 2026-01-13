# == Schema Information
#
# Table name: blogs
#
#  id               :bigint           not null, primary key
#  content          :jsonb            not null
#  deleted_at       :datetime
#  meta_description :string(500)
#  meta_title       :string(255)
#  published_at     :datetime
#  slug             :string           not null
#  status           :string           default("draft"), not null
#  title            :string           not null
#  view_count       :integer          default(0)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  author_id        :bigint           not null
#  category_id      :bigint
#  source_wp_id     :bigint
#
# Indexes
#
#  index_blogs_on_author_id     (author_id)
#  index_blogs_on_category_id   (category_id)
#  index_blogs_on_deleted_at    (deleted_at)
#  index_blogs_on_slug          (slug) UNIQUE WHERE (deleted_at IS NULL)
#  index_blogs_on_source_wp_id  (source_wp_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (author_id => admins.id)
#  fk_rails_...  (category_id => blog_categories.id)
#
FactoryBot.define do
  factory :blog do
    sequence(:title) { |n| "Blog Post #{n}" }
    sequence(:slug) { |n| "blog-post-#{n}" }
    content do
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
    status { 'draft' }
    view_count { 0 }
    meta_title { Faker::Lorem.sentence }
    meta_description { Faker::Lorem.sentence }
    association :author, factory: :admin
    category { nil }

    trait :published do
      status { 'published' }
      published_at { Time.current }
    end

    trait :with_category do
      association :category
    end
  end
end
