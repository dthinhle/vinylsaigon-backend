# == Schema Information
#
# Table name: menu_bar_sections
#
#  id           :bigint           not null, primary key
#  section_type :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_menu_bar_sections_on_section_type  (section_type) UNIQUE
#
class MenuBar::Section < ActiveRecord::Base
  self.table_name = 'menu_bar_sections'

  has_many :items, -> { order(:parent_id, :position) }, class_name: 'MenuBar::Item', foreign_key: 'menu_bar_section_id', dependent: :destroy

  validates :section_type, presence: true, inclusion: { in: %w[left main right] }
  validates :section_type, uniqueness: { message: 'has already been taken' }

  # Ensure only one right section exists
  validate :single_right_section, if: -> { section_type == 'right' }

  private

  def single_right_section
    if section_type == 'right' && MenuBar::Section.where(section_type: 'right').where.not(id: id).exists?
      errors.add(:section_type, 'Right section already exists')
    end
  end
end
