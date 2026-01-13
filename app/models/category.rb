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
class Category < ApplicationRecord
  include RelatedCategories

  has_paper_trail(
    versions: { class_name: 'PaperTrail::Version' },
    limit: 10,
  )

  belongs_to :parent, class_name: 'Category', optional: true
  has_many :children, -> { order(title: :asc) }, class_name: 'Category', foreign_key: 'parent_id', dependent: :destroy
  has_many :products, dependent: :restrict_with_exception

  has_one_attached :image do |attachable|
    attachable.variant :thumbnail, resize_to_limit: [800, 800], preprocessed: true
  end

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validate :parent_must_be_root_category

  scope :root_categories, -> { where(is_root: true) }

  def self.setup!(
    title:,
    slug: nil,
    parent: nil,
    is_root: false,
    description: nil,
    button_text: nil,
    image: nil
  )
    slug ||= Slugify.convert(title) do |generated_slug|
      !Category.exists?(slug: generated_slug)
    end

    category = create!(
      title: title,
      description: description,
      slug: slug,
      is_root: is_root,
      parent: parent,
      button_text: button_text
    )

    if image.present?
      category.image.attach(image)
    end

    category
  end

  def index_path
    paths = []
    paths << parent.index_path if parent
    paths << title
    paths.join(' > ')
  end

  private

  def parent_must_be_root_category
    return if parent.nil?

    unless parent.is_root?
      errors.add(:parent, 'must be a root category (only one level of nesting allowed)')
    end
  end
end
