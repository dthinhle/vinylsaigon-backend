# frozen_string_literal: true

class PromotionFilterService
  attr_reader :params, :errors, :active_filters

  ALLOWED_FILTERS = {
    q: String,
    title: String,
    code: String,
    active: :boolean,
    discount_type: Array,
    starts_at_from: Date,
    starts_at_to: Date,
    ends_at_from: Date,
    ends_at_to: Date,
    sort: String,
    direction: String,
    page: Integer,
    per_page: Integer
  }.freeze

  def initialize(scope:, params:, current_admin: nil, request: nil)
    raise ArgumentError, 'Request object is required' if request.nil?

    @request = request
    @scope = scope || Promotion.all
    if params.respond_to?(:permitted?) && !params.permitted?
      raise ArgumentError, 'Unpermitted parameters passed to PromotionFilterService'
    end
    @params = params.to_h.symbolize_keys

    if @params[:sort_by].present?
      sort_parts = @params[:sort_by].split('_')
      @params[:direction] = sort_parts.pop
      @params[:sort] = sort_parts.join('_')
    end

    Rails.logger.debug "[PromotionFilterService] incoming params: #{@params.inspect}"
    @errors = []
    @active_filters = {}
    @current_admin = current_admin

    map_legacy_params
    Rails.logger.debug "[PromotionFilterService] mapped params: #{@params.slice(:starts_after, :starts_before, :starts_at_from, :starts_at_to, :ends_after, :ends_before, :ends_at_from, :ends_at_to).inspect}"

    validate_and_normalize
  end

  # Public API used by Admin::PromotionsController
  # Returns [records, active_filters, filter_errors, pagy]
  def call
    rel = results
    return [rel.none, active_filters, errors, nil] unless valid?

    # Pagination: use Pagy if available, otherwise fall back to simple limit/offset
    page = @params[:page]
    per_page = @params[:per_page]

    per_page ||= Pagy.options[:limit] rescue nil
    pagy = Pagy::Offset.new(count: rel.count, page: page, limit: per_page, request: Pagy::Request.new(request: @request))
    paginated = rel.offset(pagy.offset).limit(pagy.limit)

    [paginated, active_filters, errors, pagy]
  end

  # Build the filtered relation (excluding soft-deleted records)
  def results
    return @scope.none unless valid?

    scope = @scope

    # Exclude soft-deleted records explicitly
    scope = scope.where(deleted_at: nil) if scope.respond_to?(:column_names) && scope.column_names.include?('deleted_at')

    # q: search title or code
    if (q = @active_filters[:q]).present?
      scope = scope.where("#{Promotion.table_name}.title ILIKE :q OR #{Promotion.table_name}.code ILIKE :q", q: "%#{q}%")
    end

    # title and code partial filters
    if (title = @active_filters[:title]).present?
      scope = scope.where("#{Promotion.table_name}.title ILIKE ?", "%#{title}%")
    end

    if (code = @active_filters[:code]).present?
      scope = scope.where("#{Promotion.table_name}.code ILIKE ?", "%#{code}%")
    end

    # boolean active filter
    if @active_filters.key?(:active)
      scope = scope.where(active: @active_filters[:active])
    end

    # discount_type can be a single or comma-separated list
    if (dt = @active_filters[:discount_type]).present?
      types = Array(dt)
      scope = scope.where(discount_type: types)
      @active_filters[:discount_type] = types
    end

    # Date range filters for starts_at and ends_at
    if (from = @active_filters[:starts_at_from])
      scope = scope.where("#{Promotion.table_name}.starts_at >= ?", from)
    end
    if (to = @active_filters[:starts_at_to])
      scope = scope.where("#{Promotion.table_name}.starts_at <= ?", to)
    end

    if (from_e = @active_filters[:ends_at_from])
      scope = scope.where("#{Promotion.table_name}.ends_at >= ?", from_e)
    end
    if (to_e = @active_filters[:ends_at_to])
      scope = scope.where("#{Promotion.table_name}.ends_at <= ?", to_e)
    end

    # Sorting: use separate sort + direction params and whitelist columns to avoid SQL injection
    t = Promotion.arel_table
    sort_col = @params[:sort].to_s
    direction = %w[asc desc].include?(@params[:direction].to_s) ? @params[:direction].to_s : 'desc'

    allowed = {
      'created_at'     => t[:created_at],
      'updated_at'     => t[:updated_at],
      'title'          => t[:title],
      'code'           => t[:code],
      'starts_at'      => t[:starts_at],
      'ends_at'        => t[:ends_at],
      'usage_count'    => t[:usage_count],
      'usage_limit'    => t[:usage_limit],
      'discount_value' => t[:discount_value],
      'active'         => t[:active]
    }

    col_node = allowed[sort_col]
    order_node = if col_node
                   direction == 'asc' ? col_node.asc : col_node.desc
    else
                   # default sort
                   t[:created_at].desc
    end

    scope = scope.order(order_node)

    scope
  end

  def valid?
    @errors.empty?
  end

  private

  # Map legacy filter param names from older forms to the canonical keys used by
  # this service. This method is defensive: it only assigns a canonical key when
  # the canonical key is not already present and the legacy key exists.
  def map_legacy_params
    legacy_to_canonical = {
      starts_after:  :starts_at_from,
      starts_before: :starts_at_to,
      ends_after:    :ends_at_from,
      ends_before:   :ends_at_to
    }

    legacy_to_canonical.each do |legacy, canonical|
      if @params[canonical].blank? && @params.key?(legacy) && @params[legacy].present?
        @params[canonical] = @params[legacy]
      end
    end
  end

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
    Rails.logger.debug "[PromotionFilterService] active_filters=#{@active_filters.inspect} errors=#{@errors.inspect}"
  end

  def normalize_value(value, type)
    return value if type == :boolean && !!value == value
    return value if value.is_a?(type)

    case type
    when :boolean
      ActiveModel::Type::Boolean.new.cast(value)
    when Array
      value.is_a?(Array) ? value : value.to_s.split(',').map(&:strip)
    else
      case type.name
      when 'Integer' then Integer(value)
      when 'Date' then parse_date(value)
      when 'String' then value.to_s
      else value
      end
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
