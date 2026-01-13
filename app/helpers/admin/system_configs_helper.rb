# frozen_string_literal: true

module Admin::SystemConfigsHelper
# Format SystemConfig values for display in admin views.
# - For 'maxDiscountPerDay' we format as Vietnamese đồng (no decimals, dot thousands separator).
# - Fallback: return the raw value.
def formatted_system_config_value(system_config)
  return '' if system_config.nil?

  # Format certain monetary system configs as Vietnamese đồng (VND).
  if ['maxDiscountPerDay', 'maxDiscountPerUserPerDay'].include?(system_config.name.to_s)
    # Keep only digits, convert to integer then format as VND (no decimals, dot thousands separator).
    amount = system_config.value.to_s.gsub(/[^\d]/, '').to_i
    # number_to_currency: amount, unit: '₫', delimiter: '.', precision: 0, format: '%n %u' to show "1.000 ₫"
    number_to_currency(amount, unit: '₫', delimiter: '.', precision: 0, format: '%n %u')
  else
    system_config.value
  end
end

  # Build a safe sort link for admin indexes.
  # - Avoids using user-controlled `params` directly when building URLs.
  # - Only preserves a small whitelist of top-level keys and q-subkeys.
  # - Signature kept similar to the inline helper previously used in views so changes to views are minimal.
  def safe_sort_link_for(key, label, _params, current_sort, current_dir, sortable_keys, invalid_sort_present)
    return label if invalid_sort_present

    next_dir = (current_sort.to_s == key.to_s && current_dir.to_s == 'asc') ? 'desc' : 'asc'
    arrow = (current_sort.to_s == key.to_s) ? (current_dir.to_s == 'asc' ? ' ▲' : ' ▼') : ''

    # Whitelist top-level and q sub-keys to preserve when building the URL
    allowed_top_level = %w[active per_page]
    allowed_q_keys = Array(sortable_keys) + %w[per_page active]

    query = request.query_parameters || {}

    safe_top = query.slice(*allowed_top_level)
    safe_q = {}
    if query['q'].is_a?(Hash)
      query['q'].each do |k, v|
        safe_q[k.to_s] = v if allowed_q_keys.include?(k.to_s)
      end
    end

    safe_q['sort'] = key
    safe_q['direction'] = next_dir

    merged = safe_top.merge('q' => safe_q)
    link_url = url_for(merged) rescue '#'

    link_to "#{label}#{arrow}".html_safe, link_url, class: 'inline-flex items-center'
  end
end
