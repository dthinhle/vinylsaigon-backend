module MenuBar
  class UpsertMenuService
    attr_reader :params

    def initialize(params)
      @params = params
    end

    def perform
      ActiveRecord::Base.transaction do
        begin
          upsert_section('left', params[:left_section])
          upsert_section('main', params[:main_section])
          upsert_right_section(params[:right_section])

          {
            sections: MenuBar::Section.includes(items: :sub_items).all,
            status: :success
          }
        rescue ActiveRecord::RecordInvalid => e
          raise StandardError, "Failed to update menu: #{e.message}"
        end
      end
    rescue StandardError => e
      {
        error: e.message,
        status: :error
      }
    end

    private

    def upsert_section(type, items)
      section = MenuBar::Section.find_or_create_by!(section_type: type)
      section.items.delete_all

      return unless items.present?

      items.each_with_index do |item_params, index|
        create_item(section, item_params, index + 1)
      end
    end

    def upsert_right_section(right_section)
      return unless right_section

      section = MenuBar::Section.find_or_create_by!(section_type: 'right')
      section.update!(
        image: right_section[:image_src],
        link: right_section[:link],
        label: right_section[:label]
      )
    end

    def create_item(section, item_params, position, parent = nil)
      # Guard: reject payloads that try to set an item's parent to itself (defensive)
      if item_params[:id].present? && parent.present? && parent.id == item_params[:id].to_i
        raise StandardError, 'Item cannot be its own parent'
      end

      item = section.items.create!(
        item_type: item_params[:type],
        label: item_params[:label],
        link: item_params[:link],
        position: position,
        parent: parent
      )

      return unless item_params[:sub_items].present?

      item_params[:sub_items].each_with_index do |sub_item_params, index|
        create_item(section, sub_item_params, index, item)
      end
    end
  end
end
