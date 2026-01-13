# frozen_string_literal: true

class ProductFilterService
  attr_reader :params, :errors, :active_filters

  # Define allowed filter keys and their types for validation
  ALLOWED_FILTERS = {
    q: String,
    name: String,
    category: String,
    category_ids: Array,
    brand_ids: Array,
    price_min: Float,
    price_max: Float,
    min_price: Float,
    max_price: Float,
    status: String,
    stock_status: String,
    sku: String,
    slug: String,
    min_stock_quantity: Integer,
    max_stock_quantity: Integer,
    sort_order: Integer,
    featured: :boolean,
    free_installment_fee: :boolean,
    created_after: Date,
    created_before: Date,
    flags: Array
  }.freeze

  def initialize(params = {}, relation = nil, request: nil)
    raise ArgumentError, 'Request object is required' if request.nil?

    @request = request
    @relation = relation || Product.includes(:product_variants, :brands, :category).all
    if params.respond_to?(:permitted?) && !params.permitted?
      raise ArgumentError, 'Unpermitted parameters passed to ProductFilterService'
    end
    @params = params.to_h.symbolize_keys

    if @params[:sort_by].present?
      sort_parts = @params[:sort_by].split('_')
      @params[:direction] = sort_parts.pop
      @params[:sort] = sort_parts.join('_')
    end

    @errors = []
    @active_filters = {}
    validate_and_normalize
  end

  # Returns an ActiveRecord::Relation of filtered products
  def results
    return @relation.none unless valid?

    scope = @relation

    # Apply 'q' search if present (matches product name or sku) — qualify to avoid ambiguity when joining other tables
    if (q = @active_filters[:q]).present?
      scope = scope.where("#{Product.table_name}.name ILIKE :q OR #{Product.table_name}.sku ILIKE :q", q: "%#{q}%")
    end

    ALLOWED_FILTERS.each do |key, type|
      next if key == :q
      value = @active_filters[key]
      next if value.nil?

      case key
      when :name
        scope = scope.where("#{Product.table_name}.name ILIKE ?", "%#{value}%")
      when :category
        scope = scope.where("#{Product.table_name}.category = ?", value)
      when :category_ids
        # frontend sends category_ids as array — support both single-category FK and HABTM relation
        category_ids = Array(value).map(&:to_i).reject(&:zero?)
        if category_ids.present?
          if Product.reflect_on_association(:categories)
            scope = scope.joins(:categories).where(categories: { id: category_ids }).distinct
          else
            scope = scope.where(category_id: category_ids)
          end
          @active_filters[:categories] = Category.where(id: category_ids).pluck(:title)
        end
      when :brand_ids
        # frontend sends brand_ids as array, always filter via brands join
        brand_ids = Array(value).map(&:to_i).reject(&:zero?)
        if brand_ids.present?
          scope = scope.joins(:brands).where(brands: { id: brand_ids }).distinct
          @active_filters[:brands] = Brand.where(id: brand_ids).pluck(:name)
        end
      when :price_min, :min_price
        scope = scope.where("#{Product.table_name}.original_price >= ?", value)
      when :price_max, :max_price
        scope = scope.where("#{Product.table_name}.original_price <= ?", value)
      when :status
        scope = scope.where("#{Product.table_name}.status = ?", value)
      when :stock_status
        scope = scope.where("#{Product.table_name}.stock_status = ?", value)
      when :sku
        scope = scope.where("#{Product.table_name}.sku ILIKE ?", "%#{value}%")
      when :slug
        scope = scope.where("#{Product.table_name}.slug ILIKE ?", "%#{value}%")
      when :min_stock_quantity
        scope = scope.where("#{Product.table_name}.stock_quantity >= ?", value)
      when :max_stock_quantity
        scope = scope.where("#{Product.table_name}.stock_quantity <= ?", value)
      when :sort_order
        scope = scope.where("#{Product.table_name}.sort_order = ?", value)
      when :featured
        scope = scope.where("#{Product.table_name}.featured = ?", value)
      when :free_installment_fee
        scope = scope.where("#{Product.table_name}.free_installment_fee = ?", value)
      when :created_after
        scope = scope.where("#{Product.table_name}.created_at >= ?", value)
      when :created_before
        scope = scope.where("#{Product.table_name}.created_at <= ?", value)
      when :flags
        # Filter products that have ANY of the selected flags
        scope = scope.where("#{Product.table_name}.flags && ARRAY[?]::varchar[]", Array(value))
      end
    end

    # Sorting logic - whitelist keys and build Arel order nodes to avoid SQL injection
    t = Product.arel_table
    sort_key = @params[:sort].presence_in(%w[name sku slug original_price current_price status stock_status stock_quantity featured sort_order updated_at created_at]) || 'created_at'
    sort_direction = @params[:direction].to_s == 'asc' ? :asc : :desc

    order_node =
      case sort_key
      when 'name' then sort_direction == :asc ? t[:name].asc : t[:name].desc
      when 'sku' then sort_direction == :asc ? t[:sku].asc : t[:sku].desc
      when 'slug' then sort_direction == :asc ? t[:slug].asc : t[:slug].desc
      when 'original_price'
        scope = scope.left_outer_joins(:product_variants)
                     .group("#{Product.table_name}.id")
        order_expr = sort_direction == :asc ?
          Arel.sql('MAX(product_variants.original_price) ASC NULLS LAST') :
          Arel.sql('MAX(product_variants.original_price) DESC NULLS LAST')
        return scope.order(order_expr)
      when 'current_price'
        scope = scope.left_outer_joins(:product_variants)
                     .group("#{Product.table_name}.id")
        order_expr = sort_direction == :asc ?
          Arel.sql('MIN(product_variants.current_price) ASC NULLS LAST') :
          Arel.sql('MIN(product_variants.current_price) DESC NULLS LAST')
        return scope.order(order_expr)
      when 'status' then sort_direction == :asc ? t[:status].asc : t[:status].desc
      when 'stock_status' then sort_direction == :asc ? t[:stock_status].asc : t[:stock_status].desc
      when 'stock_quantity' then sort_direction == :asc ? t[:stock_quantity].asc : t[:stock_quantity].desc
      when 'featured' then sort_direction == :asc ? t[:featured].asc : t[:featured].desc
      when 'sort_order' then sort_direction == :asc ? t[:sort_order].asc : t[:sort_order].desc
      when 'updated_at' then sort_direction == :asc ? t[:updated_at].asc : t[:updated_at].desc
      else # created_at
        sort_direction == :asc ? t[:created_at].asc : t[:created_at].desc
      end

    scope = scope.order(order_node)

    scope
  end

  def valid?
    @errors.empty?
  end

  # For compatibility with usages expecting [results, active_filters, errors]
  def apply
    [results, active_filters, errors]
  end

  # Apply filters and return paginated results with metadata.
  # Returns: [paginated_relation, active_filters, errors, pagy]
  # Accepts optional pagination params: page, per_page
  def apply_with_pagy(page: nil, per_page: nil)
    rel = results
    return [rel.none, active_filters, errors, nil] unless valid?

    count = rel.is_a?(ActiveRecord::Relation) && rel.group_values.present? ? rel.count.size : rel.count
    pagy = Pagy::Offset.new(count: count, page: page, limit: per_page, request: Pagy::Request.new(request: @request))
    paginated = rel.offset(pagy.offset).limit(pagy.limit)

    [paginated, active_filters, errors, pagy]
  end

  private

  def validate_and_normalize
    ALLOWED_FILTERS.each do |key, type|
      raw_value = @params[key]
      next if raw_value.nil? || raw_value == ''

      begin
        value = normalize_value(raw_value, type)

        @active_filters[key] = value
      rescue ArgumentError, TypeError
        @errors << "Invalid value for #{key}: #{raw_value}"
      end
    end
  end

  def normalize_value(value, type)
    return value if type == :boolean && !!value == value
    return value if type != :boolean && value.is_a?(type)
    case type
    when :boolean
      ActiveModel::Type::Boolean.new.cast(value)
    when Array
      # Accept comma-separated string or array
      value.is_a?(Array) ? value : value.to_s.split(',').map(&:strip)
    else
      case type.name
      when 'Float'
        Float(value)
      when 'Integer'
        Integer(value)
      when 'Date'
        Date.parse(value)
      when 'String'
        value.to_s
      else
        value
      end
    end
  end
end
