module MenuBar
  class SortService
    class ValidationError < StandardError; end

    def initialize(items:)
      @items = items
    end

    def call
      raise ValidationError, 'Missing items parameter' unless @items.present? && @items.is_a?(Array)

      updated_count = 0
      errors = []
      items_changing_parent = []

  grouped_items = @items.group_by { |item| item[:parent_id] || item['parent_id'] }

      ActiveRecord::Base.transaction do
        # Preload all items once (and lock them) to avoid N+1 queries from find_by inside the loop
        ids = @items.map { |it| it[:id] || it['id'] }.compact
        items_map = MenuBar::Item.where(id: ids).lock.index_by(&:id)

        grouped_items.each do |_parent_id, children|
          sorted_children = children.sort_by { |item| item[:position] || item['position'] || 0 }
          sorted_children.each do |item_data|
            id = item_data[:id] || item_data['id']
            new_position = item_data[:position] || item_data['position']
            parent_id_val = item_data[:parent_id] || item_data['parent_id']
            section_id_val = item_data[:section_id] || item_data['section_id']

            unless id.present?
              errors << { id: id, error: 'Missing id' }
              Rails.logger.warn("[MenuBar::SortService] Missing id for item: #{item_data.inspect}")
              next
            end

            # keys in items_map are integers (id from AR), handle string/int id input
            item = items_map[id.to_i]
            unless item
              errors << { id: id, error: 'Item not found' }
              Rails.logger.warn("[MenuBar::SortService] Item not found: #{id}")
              next
            end

            if item.parent_id != parent_id_val
              items_changing_parent << { item: item, old_parent_id: item.parent_id }
            end

            # Guard: prevent setting an item's parent to itself
            if parent_id_val.present? && id.to_i == parent_id_val.to_i
              errors << { id: id, error: 'cannot be parent of itself' }
              Rails.logger.warn("[MenuBar::SortService] Attempt to set parent_id to self for item #{id}")
              next
            end

            begin
              attrs = { position: new_position, parent_id: parent_id_val }
              # Update section if provided and different
              if section_id_val.present? && item.menu_bar_section_id.to_s != section_id_val.to_s
                attrs[:menu_bar_section_id] = section_id_val
              end
              success = item.update(attrs)
              if success
                updated_count += 1
              else
                errors << { id: id, error: item.errors.full_messages.to_sentence }
                Rails.logger.error("[MenuBar::SortService] Update failed for item #{id}: #{item.errors.full_messages.to_sentence}")
              end
            rescue => e
              errors << { id: id, error: e.message }
              Rails.logger.error("[MenuBar::SortService] Update exception for item #{id}: #{e.message}")
            end
          end
        end
      end

      items = MenuBar::Item.order(:parent_id, :position).pluck(:id, :parent_id, :position)
      status = errors.any? ? :partial : :success

      {
        status: status,
        updated_count: updated_count,
        errors: errors,
        items: items.map { |id, parent_id, position| { id: id, parent_id: parent_id, position: position } }
      }
    end
  end
end
