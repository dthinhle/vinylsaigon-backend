# frozen_string_literal: true

module Admin::OrdersHelper
  # Format VND integer to VND currency string
  include CurrencyHelper

  # Return Tailwind CSS classes for status badge
  def order_status_badge_class(status)
    case status.to_s
    when 'awaiting_payment'
      'bg-yellow-100 text-yellow-800'
    when 'paid'
      'bg-green-100 text-green-800'
    when 'fulfilled'
      'bg-blue-100 text-blue-800'
    when 'canceled'
      'bg-red-100 text-red-800'
    when 'refunded'
      'bg-purple-100 text-purple-800'
    when 'failed'
      'bg-gray-100 text-gray-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  # Render order customer name
  def order_customer_name(order)
    content_tag :span, order.name
  end

  # Render status badge with appropriate styling
  def order_status_badge(status)
    content_tag :span, status.humanize, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{order_status_badge_class(status)}"
  end

  # Return array of status options for dropdown
  def order_status_options
    Order.statuses.keys.map { |status| [status.humanize, status] }
  end

  # Get valid next statuses for a given order
  def valid_next_statuses(order)
    case order.status
    when 'awaiting_payment'
      statuses = %w[paid canceled]
      statuses << 'fulfilled' if order.payment_method == 'cod'
      statuses
    when 'paid'
      %w[fulfilled refunded canceled]
    when 'fulfilled'
      %w[refunded]
    else
      []
    end
  end

  # Format Vietnamese address
  def format_vn_address(address)
    return 'N/A' if address.nil?

    parts = [
      address.address,
      address.ward,
      address.district,
      address.city,
    ].compact.reject(&:blank?)

    parts.join(', ')
  end

  def order_sortable_columns
    {
      'Order Number' => 'order_number',
      'Name' => 'name',
      'Email' => 'email',
      'Status' => 'status',
      'Total' => 'total_vnd',
      'Date' => 'created_at'
    }
  end

  # Table headers order
  def order_table_headers
    [
      'Order Number',
      'Name',
      'Email',
      'Status',
      'Phone',
      'Total',
      'Date',
      'Actions',
    ]
  end

  # Renders headers with sorting links (safe: whitelist params, avoid html_safe)
  def render_order_table_headers(params)
    current_sort = params[:sort]
    current_direction = params[:direction] || 'desc'
    headers = order_table_headers
    sortable = order_sortable_columns

    # Only allow these query params to be preserved when building URLs
    permitted_keys = %i[q order_number status email from_date to_date sort direction]

    header_cells = headers.map do |header|
      if sortable[header]
        col = sortable[header]
        dir = (current_sort == col && current_direction == 'asc') ? 'desc' : 'asc'

        # Build a safe query hash from permitted params only
        safe_query = params.permit(*permitted_keys).to_h
        safe_query['sort'] = col
        safe_query['direction'] = dir
        safe_query['page'] = nil

        url = "#{request.path}?#{safe_query.to_query}"

        arrow = if current_sort == col
          current_direction == 'asc' ? ' ▲' : ' ▼'
        else
          ''
        end

        content_tag :th, class: 'px-4 py-2 text-left text-sm font-medium text-gray-500' do
          link_to url, class: "hover:underline #{current_sort == col ? 'text-gray-950' : ''}" do
            concat(header)
            concat(content_tag(:span, arrow)) unless arrow.blank?
          end
        end
      else
        # For non-sortable headers
        text_align = header == 'Actions' ? 'text-right' : 'text-left'
        content_tag :th, header, class: "px-4 py-2 #{text_align} text-sm font-medium text-gray-500"
      end
    end

    safe_join(header_cells)
  end
end
