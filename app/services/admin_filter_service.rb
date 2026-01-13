class AdminFilterService
  def initialize(params, scope)
    @params = params
    @scope = scope
  end

  def call
    filter_by_search
    filter_by_email
    filter_by_name
    apply_sorting

    @scope
  end

  private

  def filter_by_search
    return unless @params[:q].present?

    query = "%#{@params[:q]}%"
    @scope = @scope.where('email ILIKE ? OR name ILIKE ?', query, query)
  end

  def filter_by_email
    return unless @params[:email].present?

    @scope = @scope.where('email ILIKE ?', "%#{@params[:email]}%")
  end

  def filter_by_name
    return unless @params[:name].present?

    @scope = @scope.where('name ILIKE ?', "%#{@params[:name]}%")
  end

  def apply_sorting
    sort_by = @params[:sort_by]
    return @scope = @scope.order(created_at: :desc) unless sort_by.present?

    column, direction = sort_by.split('_')
    direction = direction&.downcase == 'desc' ? :desc : :asc

    case column
    when 'email'
      @scope = @scope.order(email: direction)
    when 'name'
      @scope = @scope.order(name: direction)
    when 'created'
      @scope = @scope.order(created_at: direction)
    else
      @scope = @scope.order(created_at: :desc)
    end
  end
end
