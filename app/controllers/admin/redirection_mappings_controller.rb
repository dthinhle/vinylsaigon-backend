class Admin::RedirectionMappingsController < Admin::BaseController
  include SortableParams

  before_action :set_redirection_mapping, only: [:edit, :update, :destroy]

  FILTER_LABELS = {
    'q' => 'Search',
    'old_slug' => 'Old Slug',
    'new_slug' => 'New Slug',
    'active' => 'Active',
    'sort_by' => 'Sort'
  }.freeze

  def index
    permitted = parse_sort_by_params(index_params)

    @redirection_mappings = RedirectionMapping.all

    if permitted[:q].present?
      search_term = "%#{permitted[:q].parameterize}%"
      @redirection_mappings = @redirection_mappings.where('old_slug ILIKE :search OR new_slug ILIKE :search', search: search_term)
    end

    allowed_sort_columns = %w[id old_slug new_slug active]
    allowed_directions = %w[asc desc]
    if permitted[:sort].present? && permitted[:direction].present? &&
      allowed_sort_columns.include?(permitted[:sort]) &&
      allowed_directions.include?(permitted[:direction].downcase)
      @redirection_mappings = @redirection_mappings.order("#{permitted[:sort]} #{permitted[:direction].downcase}")
    end

    @pagy, @redirection_mappings = pagy(@redirection_mappings)

    @filter_params = index_params
    @filter_labels = FILTER_LABELS
  end

  def new
    @redirection_mapping = RedirectionMapping.new
  end

  def create
    @redirection_mapping = RedirectionMapping.new(redirection_mapping_params)
    if @redirection_mapping.save
      redirect_to admin_redirection_mappings_path, notice: 'Redirection mapping was successfully created.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @redirection_mapping.update(redirection_mapping_params)
      redirect_to admin_redirection_mappings_path, notice: 'Redirection mapping was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @redirection_mapping.destroy
    redirect_to admin_redirection_mappings_path, notice: 'Redirection mapping was successfully destroyed.'
  end

  def destroy_selected
    ids = params[:ids]
    unless ids.is_a?(Array) && ids.all? { |id| id.to_s =~ /\A\d+\z/ }
      render json: { success: false, error: 'Invalid IDs parameter' }, status: :bad_request and return
    end

    begin
      RedirectionMapping.where(id: ids.map(&:to_i)).destroy_all
      render json: { success: true }
    rescue => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end

  private

  def index_params
    params.permit(:q, :old_slug, :new_slug, :active, :sort, :direction, :sort_by, :page, :per_page)
  end

  def set_redirection_mapping
    @redirection_mapping = RedirectionMapping.find(params[:id])
  end

  def redirection_mapping_params
    params.require(:redirection_mapping).permit(:old_slug, :new_slug, :active)
  end
end
