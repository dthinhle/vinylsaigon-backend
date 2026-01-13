module Admin::PromotionsHelper
  # Mapping for sortable headers
  def promotion_sortable_columns
    {
      'Title' => 'title',
      'Code' => 'code',
      'Type' => 'discount_type',
      'Value' => 'discount_value',
      'Starts' => 'starts_at',
      'Ends' => 'ends_at',
      'Usage Count' => 'usage_count',
      'Usage Limit' => 'usage_limit',
      'Active' => 'active'
    }
  end

  # Table headers order
  def promotion_table_headers
    [
      'Title',
      'Code',
      'Type',
      'Value',
      'Discount Limit (VND)',
      'Starts',
      'Ends',
      'Usage Count',
      'Usage Limit',
      'Active',
      'Actions',
    ]
  end

  # Renders headers with sorting links (mirrors brands helper convention)
  def render_promotion_table_headers(params)
    current_sort, current_direction = params[:sort_by].present? ? params[:sort_by].rpartition('_').values_at(0, 2) : [nil, nil]
    current_direction ||= 'desc'

    headers = promotion_table_headers
    sortable = promotion_sortable_columns

    headers.map do |header|
      if sortable[header]
        col = sortable[header]
        dir = (current_sort == col && current_direction == 'asc') ? 'desc' : 'asc'
        content_tag :th, class: 'px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase' do
          link_to(
            "#{header}#{current_sort == col ? (current_direction == 'asc' ? ' ▲' : ' ▼') : ''}".html_safe,
            url_for(request.query_parameters.merge(sort_by: [col, dir].join('_'), page: nil)),
            class: "hover:underline #{current_sort == col ? 'text-gray-950' : ''}"
          )
        end
      else
        # For non-sortable headers (checkbox and actions)
        classes = 'px-4 py-2'
        if header.blank?
          # Empty header (checkbox column)
          classes += ''
        else
          text_align = header == 'Actions' ? 'text-right' : 'text-left'
          classes += " #{text_align} text-sm font-medium text-gray-500"
        end
        content_tag :th, header, class: classes
      end
    end.join.html_safe
  end

  # Returns a human-friendly label and link for a PromotionUsage.redeemable.
  # Currently maps Order -> admin_order_path(redeemable). For other types we
  # attempt the polymorphic admin path and gracefully fall back to "Type #id".
  def admin_redeemable_display(usage)
    return '-' unless usage&.redeemable.present?

    redeemable = usage.redeemable
    case usage.redeemable_type
    when 'Order'
      label = "Order ##{redeemable.respond_to?(:order_number) ? redeemable.order_number : redeemable.id}"
      begin
        link_to label, admin_order_path(redeemable), class: 'text-sky-600 hover:underline'
      rescue
        label
      end
    else
      label = "#{usage.redeemable_type} ##{usage.redeemable_id}"
      begin
        link_to label, [:admin, redeemable], class: 'text-sky-600 hover:underline'
      rescue
        label
      end
    end
  end

  def promotion_usage_sortable_columns
    {
      'id' => 'id',
      'created_at' => 'created_at',
      'active' => 'active',
      'promotion_code' => 'promotion_code',
      'user_email' => 'user_email'
    }
  end

  def render_promotion_usage_table_headers(params)
    current_sort, current_direction = params[:sort_by].present? ? params[:sort_by].rpartition('_').values_at(0, 2) : [nil, nil]
    current_direction ||= 'desc'

    sortable = promotion_usage_sortable_columns

    headers = [
      { key: 'id', label: 'ID', class: 'text-left' },
      { key: 'promotion_code', label: 'Promotion code', class: 'text-left' },
      { key: nil, label: 'User', class: 'text-left' },
      { key: 'user_email', label: 'User Email', class: 'text-left' },
      { key: nil, label: 'Redeemable', class: 'text-left' },
      { key: 'active', label: 'Active', class: 'text-center' },
      { key: 'created_at', label: 'Created At', class: 'text-left' },
      { key: nil, label: 'Actions', class: 'text-right' },
    ]

    headers.map do |header|
      key = header[:key]
      label = header[:label]
      classes = "px-4 py-2 #{header[:class]} text-xs font-medium text-gray-500 uppercase"

      if key && sortable[key]
        col = sortable[key]
        dir = (current_sort == col && current_direction == 'asc') ? 'desc' : 'asc'
        content_tag :th, class: classes do
          link_to(
            "#{label}#{current_sort == col ? (current_direction == 'asc' ? ' ▲' : ' ▼') : ''}".html_safe,
            url_for(request.query_parameters.merge(sort_by: [col, dir].join('_'), page: nil)),
            class: "hover:underline #{current_sort == col ? 'text-gray-950' : ''}"
          )
        end
      else
        content_tag :th, label, class: classes
      end
    end.join.html_safe
  end
end
