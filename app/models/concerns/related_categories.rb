# frozen_string_literal: true

module RelatedCategories
  extend ActiveSupport::Concern

  included do
    # Related categories associations
    has_many :related_category_relations, class_name: 'RelatedCategory', foreign_key: 'category_id', dependent: :destroy
    has_many :inverse_related_category_relations, class_name: 'RelatedCategory', foreign_key: 'related_category_id', dependent: :destroy
    has_many :related_categories, through: :related_category_relations, source: :related_category
    has_many :inverse_related_categories, through: :inverse_related_category_relations, source: :category
  end

  # Get all related categories (both directions)
  def all_related_categories
    Category.joins(
      "LEFT JOIN related_categories rc1 ON rc1.related_category_id = categories.id AND rc1.category_id = ?
       LEFT JOIN related_categories rc2 ON rc2.category_id = categories.id AND rc2.related_category_id = ?",
      id, id
    ).where('rc1.id IS NOT NULL OR rc2.id IS NOT NULL')
     .distinct
     .where.not(id: id)
  end

  # Get related categories with their weights for randomized selection
  def weighted_related_categories
    # Get relations where this category is the source
    outgoing = RelatedCategory.includes(:related_category)
                             .where(category: self)
                             .map { |rc| { category: rc.related_category, weight: rc.weight } }

    # Get relations where this category is the target
    incoming = RelatedCategory.includes(:category)
                             .where(related_category: self)
                             .map { |rc| { category: rc.category, weight: rc.weight } }

    (outgoing + incoming).uniq { |item| item[:category].id }
  end

  # Get random related categories based on weights
  def random_related_categories(limit: 8)
    weighted_categories = weighted_related_categories
    return [] if weighted_categories.empty?

    # Ensure we don't request more than available
    limit = [limit, weighted_categories.size].min

    # Use weighted random selection without replacement
    selected = []
    remaining_categories = weighted_categories.dup

    limit.times do
      break if remaining_categories.empty?

      # Calculate total weight of remaining categories
      total_weight = remaining_categories.sum { |item| item[:weight] }

      # If total_weight is zero or less, break to avoid ArgumentError
      break if total_weight <= 0

      # Generate random number between 1 and total_weight
      random_weight = rand(1..total_weight)

      # Find the category that corresponds to this weight
      current_weight = 0
      selected_category = nil

      remaining_categories.each_with_index do |item, index|
        current_weight += item[:weight]
        if current_weight >= random_weight
          selected_category = item[:category]
          remaining_categories.delete_at(index)
          break
        end
      end

      selected << selected_category if selected_category
    end

    selected
  end

  # Create bidirectional relationship with another category
  def relate_to!(other_category, weight)
    RelatedCategory.create_bidirectional!(self, other_category, weight)
  end

  # Update relationship weight with another category
  def update_relation_with!(other_category, weight)
    RelatedCategory.update_bidirectional!(self, other_category, weight)
  end

  # Remove relationship with another category
  def unrelate_from!(other_category)
    RelatedCategory.destroy_bidirectional!(self, other_category)
  end
end
