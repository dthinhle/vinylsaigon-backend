module Admin::BaseHelper
  include CurrencyHelper

  DEFAULT_TIMEZONE = 'Hanoi'.freeze

  def format_price(price_value)
    number_to_currency(price_value, unit: 'đ', precision: 0, format: '%n %u')
  end

  def format_datetime(datetime, position: 'right')
    return '-' if datetime.blank?

    distance_time = [time_ago_in_words(datetime), 'ago'].join(' ')
    content_tag(:span,
      class: 'tooltip-trigger',
      data: {
        controller: 'tooltip',
        tooltip_text_value: datetime.in_time_zone(DEFAULT_TIMEZONE).strftime('%H:%M %p %d/%m/%Y'),
        tooltip_position_value: position
      }
    ) do
      content_tag(:span, distance_time)
    end
  end

  def format_date(date)
    return '-' if date.blank?
    date.in_time_zone(DEFAULT_TIMEZONE).strftime('%Y-%m-%d')
  end

  def render_boolean_badge(value)
    css_class = value ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
    text = value ? 'Yes' : 'No'
    content_tag(:span, text, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{css_class}")
  end

  def render_admin_list_table(collection:, pagy: nil, &block)
    render partial: 'admin/shared/list_table',
           locals: { collection: collection, pagy: pagy, content: capture(&block) }
  end

  def render_filter_chips(filter_params:, filter_labels:, clear_path:)
    renderer = FilterChipRenderer.new(filter_params, filter_labels)
    chips = renderer.render_chips

    render partial: 'admin/shared/filter_chips',
           locals: { chips: chips, filter_params: filter_params, clear_path: clear_path }
  end

  def render_empty_state(colspan:, icon: '🔍', title: 'No results found', message: 'Try adjusting your filters or search terms.')
    render partial: 'admin/shared/empty_state',
           locals: { colspan: colspan, icon: icon, title: title, message: message }
  end

  def render_bulk_actions_row(controller_name:, colspan:, delete_path: nil, &custom_actions)
    render partial: 'admin/shared/bulk_actions_row',
           locals: {
             controller_name: controller_name,
             colspan: colspan,
             delete_path: delete_path,
             custom_actions: (capture(&custom_actions) if block_given?)
           }
  end

  def render_action_button(path, icon:, type: :show, **options)
    color_classes = case type
    when :show, :edit
      'border-sky-100 text-sky-500 hover:border-sky-200 hover:text-sky-700'
    when :delete, :destroy
      'border-red-100 text-red-700 hover:border-red-200'
    else
      'border-gray-100 text-gray-700 hover:border-gray-200'
    end

    base_class = "btn btn-xs border #{color_classes} px-2 py-1 rounded flex items-center justify-center"
    options[:class] = "#{base_class} #{options[:class]}".strip
    options[:title] ||= type.to_s.titleize
    options[:aria] ||= { label: type.to_s.titleize }

    if type == :delete || type == :destroy
      options[:method] = :delete
      options[:form] ||= {
        "data-controller": 'confirm',
        "data-confirm-message-value": options.delete(:confirm_message) || 'Are you sure?'
      }
      options[:class] += ' cursor-pointer'
      button_to(path, **options) do
        content_tag(:span, icon, class: 'material-icons text-sm!', 'aria-hidden': true)
      end
    else
      link_to(path, **options) do
        content_tag(:span, icon, class: 'material-icons text-sm!', 'aria-hidden': true)
      end
    end
  end
end
