# == Schema Information
#
# Table name: redirection_mappings
#
#  id         :bigint           not null, primary key
#  active     :boolean          not null
#  new_slug   :string           not null
#  old_slug   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_redirection_mappings_on_old_slug             (old_slug) UNIQUE
#  index_redirection_mappings_on_old_slug_and_active  (old_slug,active)
#
class RedirectionMapping < ApplicationRecord
  validates :old_slug, presence: true, uniqueness: true
  validates :new_slug, presence: true
  validate :no_circular_redirect

  after_commit :revalidate_menu_cache, on: [:create, :update, :destroy]

  private

  def no_circular_redirect
    return unless old_slug.present? && new_slug.present?

    # Check for direct circular redirect (A->A)
    if old_slug == new_slug
      errors.add(:base, 'old slug and new slug cannot be the same (circular redirect)')
      return
    end

    # Check for indirect circular redirects (A->B->A, A->B->C->A, etc.)
    if creates_circular_redirect?
      errors.add(:base, 'This redirect would create a circular redirect chain')
    end
  end

  def creates_circular_redirect?
    visited_slugs = Set.new
    current_slug = new_slug

    # Follow the redirect chain to detect cycles
    while current_slug
      # If we've seen this slug before, we have a cycle
      return true if visited_slugs.include?(current_slug)

      # If we've reached our starting point, we have a cycle
      return true if current_slug == old_slug

      visited_slugs.add(current_slug)

      # Find the next redirect in the chain (excluding the current record being validated)
      next_redirect = RedirectionMapping.where(old_slug: current_slug)
                                       .where(active: true)

      # If this is an update operation, exclude the current record from the search
      next_redirect = next_redirect.where.not(id: id) if persisted?

      next_redirect = next_redirect.first

      # If no more redirects found, chain ends safely
      break unless next_redirect

      current_slug = next_redirect.new_slug

      # Safety check: prevent infinite loops by limiting chain length
      return true if visited_slugs.size > 100
    end

    false
  end

  def revalidate_menu_cache
    FrontendRevalidateJob.perform_later('Global')
  end
end
