# frozen_string_literal: true

class Api::OrderListService
  attr_reader :params, :errors, :user

  ALLOWED_PERIODS = %w[last6months lastyear alltime].freeze
  ALLOWED_STATUSES = %w[awaiting_payment paid canceled confirmed fulfilled refunded failed].freeze
  ALLOWED_PAYMENT_STATUSES = %w[pending paid failed].freeze
  MAX_PER_PAGE = 50
  DEFAULT_PER_PAGE = 10

  def initialize(user:, params: {})
    @user = user
    @params = params.to_h.symbolize_keys
    @errors = []
  end

  def call
    return { orders: [], pagination: nil, errors: ['User is required'] } unless user

    scope = build_scope

    # Return early if validation errors
    unless errors.empty?
      return { orders: [], pagination: nil, errors: errors }
    end

    paginated_scope, pagination_info = paginate(scope)
    orders_with_includes = paginated_scope.includes(
      order_items: %i[product_variant product]
    )

    {
      orders: orders_with_includes,
      pagination: pagination_info,
      errors: []
    }
  end

  private

  def build_scope
    scope = Order.where(user_id: user.id)

    scope = apply_status_filter(scope)
    scope = apply_payment_status_filter(scope)
    scope = apply_search_filter(scope)
    scope = apply_period_filter(scope)
    scope = apply_date_range_filters(scope)

    # Default ordering
    scope.order(created_at: :desc)
  end

  def apply_status_filter(scope)
    return scope unless params[:status].present?

    if ALLOWED_STATUSES.include?(params[:status])
      scope.where(status: params[:status])
    else
      errors << "Invalid status value. Must be one of: #{ALLOWED_STATUSES.join(', ')}"
      scope
    end
  end

  def apply_payment_status_filter(scope)
    return scope unless params[:payment_status].present?

    if ALLOWED_PAYMENT_STATUSES.include?(params[:payment_status])
      scope.where(payment_status: params[:payment_status])
    else
      errors << "Invalid payment_status value. Must be one of: #{ALLOWED_PAYMENT_STATUSES.join(', ')}"
      scope
    end
  end

  def apply_search_filter(scope)
    return scope unless params[:search].present?

    search_term = "%#{params[:search]}%"
    scope.where('order_number ILIKE ?', search_term)
  end

  def apply_period_filter(scope)
    return scope unless params[:period].present?

    case params[:period]
    when 'last6months'
      six_months_ago = 6.months.ago.beginning_of_day
      scope.where('created_at >= ?', six_months_ago)
    when 'lastyear'
      last_year = 1.year.ago.beginning_of_year
      end_of_last_year = 1.year.ago.end_of_year
      scope.where(created_at: last_year..end_of_last_year)
    when 'alltime'
      scope # No date filtering for all time
    else
      errors << "Invalid period value. Must be one of: #{ALLOWED_PERIODS.join(', ')}"
      scope
    end
  end

  def apply_date_range_filters(scope)
    scope = apply_from_date_filter(scope)
    scope = apply_to_date_filter(scope)
    scope
  end

  def apply_from_date_filter(scope)
    return scope unless params[:from_date].present?

    begin
      from_date = Date.parse(params[:from_date])
      scope.where('created_at >= ?', from_date.beginning_of_day)
    rescue ArgumentError
      errors << 'Invalid from_date format'
      scope
    end
  end

  def apply_to_date_filter(scope)
    return scope unless params[:to_date].present?

    begin
      to_date = Date.parse(params[:to_date])
      scope.where('created_at <= ?', to_date.end_of_day)
    rescue ArgumentError
      errors << 'Invalid to_date format'
      scope
    end
  end

  def paginate(scope)
    page = [params[:page].to_i, 1].max
    per_page = [params[:per_page]&.to_i || DEFAULT_PER_PAGE, MAX_PER_PAGE].min

    total_count = scope.count
    total_pages = (total_count.to_f / per_page).ceil

    paginated_scope = scope.offset((page - 1) * per_page).limit(per_page)

    pagination_info = {
      current_page: page,
      per_page: per_page,
      total_pages: total_pages,
      total_count: total_count
    }

    [paginated_scope, pagination_info]
  end
end
