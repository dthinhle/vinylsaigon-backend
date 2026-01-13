json.left_section do
  if (left = sections.find { it.section_type == 'left' })
    json.array! left.items.filter { it.parent_id.nil? } do |item|
      json.type item.item_type
      json.label item.label
      json.link item.link if item.link.present?

      if item.sub_items.any?
        json.sub_items item.sub_items do |sub_item|
          json.type sub_item.item_type
          json.label sub_item.label
          json.link sub_item.link if sub_item.link.present?
        end
      end
    end
  else
    json.array! []
  end
end

json.main_section do
  if (main = sections.find { it.section_type == 'main' })
    json.array! main.items.filter { it.parent_id.nil? } do |item|
      json.type item.item_type
      json.label item.label
      json.link item.link if item.link.present?

      if item.sub_items.any?
        json.sub_items item.sub_items do |sub_item|
          json.type sub_item.item_type
          json.label sub_item.label
          json.link sub_item.link if sub_item.link.present?
        end
      end
    end
  else
    json.array! []
  end
end

json.right_section do
  if featured_product
    json.image_src ImagePathService.new(featured_product.images.first).path
    json.link '/' + featured_product.slug
    json.label featured_product.name
  end
end
