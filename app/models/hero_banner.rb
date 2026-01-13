# == Schema Information
#
# Table name: hero_banners
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime
#  description :text
#  main_title  :string
#  text_color  :string
#  url         :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_hero_banners_on_deleted_at  (deleted_at)
#
class HeroBanner < ApplicationRecord
  has_one_attached :image

  has_paper_trail(
    versions: { class_name: 'PaperTrail::Version' },
    limit: 10,
  )

  validates :image, presence: true

  # Ensure image is attached and is an image file
  validate :acceptable_image

  after_commit :revalidate_banner_cache, on: [:create, :update, :destroy]

  ACCEPTABLE_TYPES = ['image/jpeg', 'image/png', 'image/webp']

  private

  def acceptable_image
    return unless image.attached?

    unless image.blob.byte_size <= 10.megabyte
      errors.add(:image, 'is too big (should be less than 10MB)')
    end

    acceptable_types = ACCEPTABLE_TYPES
    unless acceptable_types.include?(image.content_type)
      errors.add(:image, 'must be a JPEG or PNG')
    end
  end

  def revalidate_banner_cache
    FrontendRevalidateJob.perform_later('Global')
  end
end
