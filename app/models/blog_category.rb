# == Schema Information
#
# Table name: blog_categories
#
#  id           :bigint           not null, primary key
#  blogs_count  :integer          default(0), not null
#  deleted_at   :datetime
#  name         :string           not null
#  slug         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  source_wp_id :bigint
#
# Indexes
#
#  index_blog_categories_on_deleted_at    (deleted_at)
#  index_blog_categories_on_slug          (slug) UNIQUE
#  index_blog_categories_on_source_wp_id  (source_wp_id) UNIQUE
#
class BlogCategory < ApplicationRecord
  has_many :blogs, dependent: :nullify, foreign_key: 'category_id'
  validates :name, presence: true
end
