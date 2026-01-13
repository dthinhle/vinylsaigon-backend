# frozen_string_literal: true

require 'active_support/concern'
require 'slugify'

module Sluggable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_slug, if: :slug_blank?
    validates :slug, uniqueness: true, presence: true
  end

  def slug_blank?
    slug.blank?
  end

  def generate_slug
    return if slug.present?

    if respond_to?(:name) && name.present?
      self.slug = Slugify.convert(name, true)
    elsif respond_to?(:title) && title.present?
      self.slug = Slugify.convert(title, true)
    end
  end
end
