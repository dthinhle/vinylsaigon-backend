module Admin::AdminsHelper
  def render_admin_table_headers(params)
    headers = [
      { key: 'name', label: 'Name', sortable: true },
      { key: 'email', label: 'Email', sortable: true },
      { key: 'created_at', label: 'Created At', sortable: true },
      { key: 'order_notify', label: 'Order Notifications', sortable: false },
      { key: 'actions', label: 'Actions', sortable: false },
    ]

    content = []

    headers.each do |header|
      if header[:sortable]
        content << admin_sortable_header(header[:key], header[:label], params)
      else
        text_align = (header[:label] == 'Actions' || header[:label] == 'Order Notifications') ? 'text-center' : 'text-left'
        content << content_tag(:th, header[:label], class: "px-4 py-2 #{text_align} font-medium text-gray-700")
      end
    end

    safe_join(content)
  end

  private

  def admin_sortable_header(key, label, params)
    current_sort, current_direction = params[:sort_by].present? ? params[:sort_by].rpartition('_').values_at(0, 2) : [nil, nil]
    current_direction ||= 'desc'

    if current_sort == key.to_s
      new_direction = current_direction == 'asc' ? 'desc' : 'asc'
      css_class = 'px-4 py-2 text-left font-medium text-gray-950 cursor-pointer hover:bg-gray-100 select-none'

      if current_direction == 'asc'
        label_with_icon = "#{label} ▲"
      else
        label_with_icon = "#{label} ▼"
      end
    else
      new_direction = 'asc'
      css_class = 'px-4 py-2 text-left font-medium text-gray-700 cursor-pointer hover:bg-gray-100 select-none'
      label_with_icon = label
    end

    sort_value = [key, new_direction].join('_')

    content_tag(:th, class: css_class) do
      link_to label_with_icon, admin_admins_path(params.permit(:q, :email, :name, :created_from, :created_to).to_h.merge(sort_by: sort_value)), class: 'block w-full h-full'
    end
  end
end
