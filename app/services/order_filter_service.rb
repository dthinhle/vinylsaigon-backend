# frozen_string_literal: true

class OrderFilterService
  attr_reader :params, :errors, :active_filters

  ALLOWED_FILTERS = {
    q: String,
    order_number: String,
    status: String,
    email: String,          # For denormalized email
    phone_number: String,   # For denormalized phone
    name: String,           # For denormalized name
    promotion_code: String, # To filter by applied promotion
    contains_free_installment: :boolean,
    installment_only: :boolean,
    fully_free_installment: :boolean,
    from_date: Date,
    to_date: Date,
    sort: String,
    direction: String,
    page: Integer,
    per_page: Integer
  }.freeze

  def initialize(scope:, params:, current_admin: nil, request: nil)
    raise ArgumentError, 'Request object is required' if request.nil?

    @request = request
    @scope = scope || Order.all
    if params.respond_to?(:permitted?) && !params.permitted?
      raise ArgumentError, 'Unpermitted parameters passed to OrderFilterService'
    end
    @params = params.to_h.symbolize_keys

    if @params[:sort_by].present?
      sort_parts = @params[:sort_by].split('_')
      @params[:direction] = sort_parts.pop
      @params[:sort] = sort_parts.join('_')
    end

    @errors = []
    @active_filters = {}
    @current_admin = current_admin
    validate_and_normalize
  end

  # Public API used by Admin::OrdersController
  # Returns [records, active_filters, filter_errors, pagy]
  def call
    rel = results
    return [rel.none, active_filters, errors, nil] unless valid?

    # Pagination: use Pagy if available, otherwise fall back to simple limit/offset
    page = @params[:page]
    per_page = @params[:per_page]

    # Use configured default items if per_page not provided
    per_page ||= Pagy.options[:limit] rescue nil
    pagy = Pagy::Offset.new(count: rel.count, page: page, limit: per_page, request: Pagy::Request.new(request: @request))
    paginated = rel.offset(pagy.offset).limit(pagy.limit)

    [paginated, active_filters, errors, pagy]
  end

  # Build the filtered relation
  def results
    return @scope.none unless valid?

    scope = @scope

    # q: global search across multiple fields
    if (q = @active_filters[:q]).present?
      conditions = [
        'orders.order_number ILIKE :q',
        'users.email ILIKE :q',
        'orders.email ILIKE :q',
        'orders.phone_number ILIKE :q',
        'orders.name ILIKE :q',
      ].join(' OR ')
      scope = scope.left_joins(:user).where(conditions, q: "%#{q}%")
    end

    # Specific filters
    if (order_number = @active_filters[:order_number]).present?
      scope = scope.where('orders.order_number ILIKE ?', "%#{order_number}%")
    end

    if (status = @active_filters[:status]).present?
      scope = scope.where(status: status)
    end

    if (email = @active_filters[:email]).present?
      scope = scope.where('orders.email ILIKE ?', "%#{email}%")
    end

    if (phone = @active_filters[:phone_number]).present?
      scope = scope.where('orders.phone_number ILIKE ?', "%#{phone}%")
    end

    if (name = @active_filters[:name]).present?
      scope = scope.where('orders.name ILIKE ?', "%#{name}%")
    end

    if (promo_code = @active_filters[:promotion_code]).present?
      scope = scope.joins(promotion_usages: :promotion)
                   .where('promotions.code ILIKE ?', "%#{promo_code}%")
    end

    # Date range filters for created_at
    if (from_date = @active_filters[:from_date])
      scope = scope.where('orders.created_at >= ?', from_date.beginning_of_day)
    end
    if (to_date = @active_filters[:to_date])
      scope = scope.where('orders.created_at <= ?', to_date.end_of_day)
    end

    # Free installment filters
    if @active_filters[:contains_free_installment] == true
      # Use subquery to avoid DISTINCT issues with ORDER BY
      order_ids = Order.joins(order_items: :product)
                       .where(products: { free_installment_fee: true })
                       .distinct
                       .pluck(:id)
      scope = scope.where(id: order_ids)
    end

    if @active_filters[:fully_free_installment] == true
      scope = scope.where.not(
        'EXISTS (SELECT 1 FROM order_items oi JOIN products p ON p.id = oi.product_id WHERE oi.order_id = orders.id AND p.free_installment_fee = FALSE)'
      )
    end

    # Installment payment filter: check orders.metadata payment_method
    if @active_filters[:installment_only] == true
      scope = scope.where("orders.metadata ->> 'payment_method' = 'installment'")
    elsif @active_filters[:installment_only] == false
      scope = scope.where("COALESCE(orders.metadata ->> 'payment_method', '') != 'installment'")
    end

    # Sorting: use separate sort + direction params and whitelist columns to avoid SQL injection
    t = Order.arel_table
    sort_col = @params[:sort].to_s
    direction = %w[asc desc].include?(@params[:direction].to_s) ? @params[:direction].to_s : 'desc'

    allowed = {
      'created_at'     => t[:created_at],
      'updated_at'     => t[:updated_at],
      'order_number'   => t[:order_number],
      'status'         => t[:status],
      'total_vnd'      => t[:total_vnd]
    }

    col_node = allowed[sort_col]
    order_node = if col_node
                   direction == 'asc' ? col_node.asc : col_node.desc
    else
                   # default sort: newest first
                   t[:created_at].desc
    end

    scope = scope.order(order_node)

    scope
  end

  def valid?
    @errors.empty?
  end

  private

  def validate_and_normalize
    ALLOWED_FILTERS.each do |key, type|
      raw = @params[key]
      next if raw.nil? || raw == ''

      begin
        value = normalize_value(raw, type)
        @active_filters[key] = value
      rescue ArgumentError, TypeError
        @errors << "Invalid value for #{key}: #{raw}"
      end
    end
    Rails.logger.debug "[OrderFilterService] active_filters=#{@active_filters.inspect} errors=#{@errors.inspect}"
  end

  def normalize_value(value, type)
    return value if type == :boolean && !!value == value
    return value if type != :boolean && value.is_a?(type)

    case type
    when :boolean
      ActiveModel::Type::Boolean.new.cast(value)
    when Integer
      Integer(value)
    when Date
      parse_date(value)
    when String
      value.to_s
    else
      value
    end
  end

  def parse_date(value)
    # Support both date and datetime strings; prefer Time.zone.parse if available
    begin
      if value.is_a?(String)
        parsed = if defined?(Time) && Time.respond_to?(:zone) && Time.zone
                   Time.zone.parse(value)
        else
                   Time.parse(value)
        end
        parsed
      else
        value
      end
    rescue StandardError
      raise ArgumentError, "Invalid date: #{value}"
    end
  end
end
