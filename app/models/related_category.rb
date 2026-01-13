# == Schema Information
#
# Table name: related_categories
#
#  id                  :bigint           not null, primary key
#  weight              :integer          not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  category_id         :bigint           not null
#  related_category_id :bigint           not null
#
# Indexes
#
#  index_related_categories_on_category_id          (category_id)
#  index_related_categories_on_related_category_id  (related_category_id)
#  index_related_categories_unique                  (category_id,related_category_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (related_category_id => categories.id)
#
class RelatedCategory < ApplicationRecord
  belongs_to :category, class_name: 'Category'
  belongs_to :related_category, class_name: 'Category'

  validates :weight, presence: true, inclusion: { in: 0..10 }
  validates :category_id, uniqueness: { scope: :related_category_id }
  validate :cannot_relate_to_self

  scope :by_weight, ->(weight) { where(weight: weight) }
  scope :ordered_by_weight_desc, -> { order(weight: :desc) }
  scope :for_category, ->(category) { where(category: category) }

  # Class method to create bidirectional relationship
  def self.create_bidirectional!(category1, category2, weight)
    transaction do
      # Create both directions if they don't exist
      find_or_create_by!(category: category1, related_category: category2) do |rel|
        rel.weight = weight
      end

      find_or_create_by!(category: category2, related_category: category1) do |rel|
        rel.weight = weight
      end
    end
  end

  # Class method to update bidirectional relationship
  def self.update_bidirectional!(category1, category2, weight)
    transaction do
      where(category: category1, related_category: category2).update_all(weight: weight)
      where(category: category2, related_category: category1).update_all(weight: weight)
    end
  end

  # Class method to destroy bidirectional relationship
  def self.destroy_bidirectional!(category1, category2)
    transaction do
      where(category: category1, related_category: category2).destroy_all
      where(category: category2, related_category: category1).destroy_all
    end
  end

  private

  def cannot_relate_to_self
    if category_id == related_category_id
      errors.add(:related_category, 'cannot be the same as category')
    end
  end
end
