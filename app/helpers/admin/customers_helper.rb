module Admin::CustomersHelper
  def render_customer_table_headers(params)
    headers = [
      { key: 'email', label: 'Email', sortable: true },
      { key: 'name', label: 'Name', sortable: true },
      { key: 'phone_number', label: 'Phone', sortable: true },
      { key: 'disabled', label: 'Status', sortable: true },
      { key: 'created_at', label: 'Created', sortable: true },
      { key: 'updated_at', label: 'Updated', sortable: true },
      { key: 'actions', label: 'Actions', sortable: false },
    ]

    content = []

    headers.each do |header|
      if header[:sortable]
        content << customer_sortable_header(header[:key], header[:label], params)
      else
        text_align = header[:label] == 'Actions' ? 'text-right' : 'text-left'
        content << content_tag(:th, header[:label], class: "p-2 #{text_align} text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50")
      end
    end

    safe_join(content)
  end

  def customer_status_badge(customer)
    case customer.disabled
    when false
      content_tag(:span, 'Active', class: 'inline-block px-2 py-1 text-xs rounded bg-green-100 text-green-800')
    when true
      content_tag(:span, 'Inactive', class: 'inline-block px-2 py-1 text-xs rounded bg-yellow-100 text-yellow-800')
    else
      content_tag(:span, 'Unknown', class: 'inline-block px-2 py-1 text-xs rounded bg-gray-100 text-gray-800')
    end
  end

  def customer_full_name(customer)
    customer.name.presence || 'N/A'
  end

  def device_icon(device_type)
    case device_type
    when 'mobile'
      'smartphone'
    when 'tablet'
      'tablet'
    else
      'computer'
    end
  end

  private

  def customer_sortable_header(key, label, params)
    current_sort, current_direction = params[:sort_by].present? ? params[:sort_by].rpartition('_').values_at(0, 2) : [nil, nil]
    current_direction ||= 'desc'

    if current_sort == key.to_s
      new_direction = current_direction == 'asc' ? 'desc' : 'asc'
      css_class = 'p-2 text-left text-xs font-medium uppercase tracking-wider bg-gray-50 cursor-pointer hover:bg-gray-100 select-none text-gray-950'

      if current_direction == 'asc'
        label_with_icon = "#{label} ▲"
      else
        label_with_icon = "#{label} ▼"
      end
    else
      new_direction = 'asc'
      css_class = 'p-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50 cursor-pointer hover:bg-gray-100 select-none'
      label_with_icon = label
    end

    sort_value = [key, new_direction].join('_')

    content_tag(:th, class: css_class) do
      link_to label_with_icon, admin_customers_path(params.permit(:q, :email, :disabled, :created_from, :created_to).to_h.merge(sort_by: sort_value)), class: 'block w-full h-full'
    end
  end
end
