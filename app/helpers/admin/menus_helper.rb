module Admin::MenusHelper
  # Build hierarchical options for a given menu section.
  # Returns an array of [label, id] pairs suitable for options_for_select.
  def menu_items_for_select(section)
    # Avoid N+1: build an in-memory parent->children map from section.items
    items = section.items.to_a
    grouped = items.group_by { |it| it.parent_id }

    build = lambda do |parent_id = nil, prefix = ''|
      (grouped[parent_id] || [])
        .sort_by(&:position)
        .flat_map do |node|
          label = "#{prefix}#{node.label}"
          [[label, node.id]] + build.call(node.id, "#{prefix}-- ")
        end
    end

    build.call(nil, '')
  end
end
