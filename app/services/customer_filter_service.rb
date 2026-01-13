class CustomerFilterService
  def initialize(params, scope = User.all)
    @params = params.to_h.symbolize_keys

    if @params[:sort_by].present?
      sort_parts = @params[:sort_by].split('_')
      @params[:direction] = sort_parts.pop
      @params[:sort] = sort_parts.join('_')
    end

    @scope = scope
  end

  def call
    filter_by_search
    filter_by_email
    filter_by_disabled
    filter_by_date_range
    apply_sorting
    @scope
  end

  private

  def filter_by_search
    return unless @params[:q].present?

    query = @params[:q].strip
    @scope = @scope.where(
      'LOWER(email) LIKE :query OR LOWER(name) LIKE :query OR phone_number LIKE :query',
      query: "%#{query.downcase}%"
    )
  end

  def filter_by_email
    return unless @params[:email].present?

    @scope = @scope.where('email ILIKE ?', "%#{@params[:email].strip}%")
  end

  def filter_by_disabled
    return unless @params[:disabled].present?

    case @params[:disabled]
    when 'false'
      @scope = @scope.where(disabled: false)
    when 'true'
      @scope = @scope.where(disabled: true)
    end
  end

  def filter_by_date_range
    if @params[:created_from].present?
      begin
        from_date = Date.parse(@params[:created_from])
        @scope = @scope.where('created_at >= ?', from_date.beginning_of_day)
      rescue Date::Error
        # Invalid date format, ignore filter
      end
    end

    if @params[:created_to].present?
      begin
        to_date = Date.parse(@params[:created_to])
        @scope = @scope.where('created_at <= ?', to_date.end_of_day)
      rescue Date::Error
        # Invalid date format, ignore filter
      end
    end
  end

  def apply_sorting
    sort_field = @params[:sort].presence || 'created_at'
    sort_direction = @params[:direction].presence&.downcase == 'asc' ? 'asc' : 'desc'

    # Validate sort field to prevent SQL injection
    valid_sort_fields = %w[
      email name created_at updated_at phone_number disabled
      reset_password_sent_at remember_created_at
    ]

    sort_field = 'created_at' unless valid_sort_fields.include?(sort_field)

    @scope = @scope.order("#{sort_field} #{sort_direction}")
  end
end
