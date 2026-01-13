module TooltipHelper
  def tooltip_icon(text, position: 'top')
    content_tag(:span,
      class: 'tooltip-trigger',
      data: {
        controller: 'tooltip',
        tooltip_text_value: text,
        tooltip_position_value: position
      }
    ) do
      content_tag(:span, 'help', class: 'material-icons text-base! text-gray-400 hover:text-gray-600 cursor-help inline-block')
    end
  end
end
