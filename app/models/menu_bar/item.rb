# == Schema Information
#
# Table name: menu_bar_items
#
#  id                  :bigint           not null, primary key
#  image               :string
#  item_type           :string           not null
#  label               :string           not null
#  link                :string
#  position            :integer          not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  menu_bar_section_id :bigint           not null
#  parent_id           :bigint
#
# Indexes
#
#  index_menu_bar_items_on_menu_bar_section_id  (menu_bar_section_id)
#  index_menu_bar_items_on_parent_id            (parent_id)
#  index_menu_bar_items_on_position             (position)
#
# Foreign Keys
#
#  fk_rails_...  (menu_bar_section_id => menu_bar_sections.id)
#  fk_rails_...  (parent_id => menu_bar_items.id)
#
class MenuBar::Item < ActiveRecord::Base
  self.table_name = 'menu_bar_items'

  belongs_to :section, class_name: 'MenuBar::Section', foreign_key: 'menu_bar_section_id'
  # Alias for legacy code and view helpers that expect `menu_bar_section`
  belongs_to :menu_bar_section, class_name: 'MenuBar::Section', foreign_key: 'menu_bar_section_id'
  belongs_to :parent, class_name: 'MenuBar::Item', optional: true
  has_many :sub_items, -> { order(:parent_id, :position) }, class_name: 'MenuBar::Item', foreign_key: 'parent_id', dependent: :destroy
  accepts_nested_attributes_for :sub_items, allow_destroy: true

  has_one_attached :image

  validates :item_type, presence: true, inclusion: %w[link header]

  validates :label, presence: true
  validates :link, presence: true, if: -> { item_type == 'link' }

  # Prevent assigning an item as its own parent
  validate :parent_cannot_be_self

  after_commit :revalidate_menu_cache, on: [:create, :update, :destroy]

  def parent_cannot_be_self
    return unless parent_id.present?
    if parent_id == id
      errors.add(:parent_id, 'cannot be parent of itself')
    end
  end

  acts_as_list scope: [:menu_bar_section_id, :parent_id]

  def as_json(options = {})
    super(
      options.merge(
        except: [:created_at, :updated_at, :menu_bar_section_id, :parent_id],
        methods: [:sub_items]
      )
    ).merge(position: position)
  end

  private

  def revalidate_menu_cache
    FrontendRevalidateJob.perform_later('Global')
  end
end
