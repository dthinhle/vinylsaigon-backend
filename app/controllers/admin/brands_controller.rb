class Admin::BrandsController < Admin::BaseController
  include SortableParams
  include Admin::ProductListable

  before_action :set_brand, only: [:show, :edit, :update, :destroy]

  FILTER_LABELS = {
    'q' => 'Search',
    'name' => 'Name',
    'slug' => 'Slug',
    'created_after' => 'Created After',
    'created_before' => 'Created Before',
    'sort_by' => 'Sort',
    'flags' => 'Flags'
  }.freeze

  def index
    permitted = parse_sort_by_params(index_params)

    @brands, @active_filters, @filter_errors, @pagy = BrandService.filter_brands(permitted, request: request)

    @filter_params = index_params
    @filter_labels = FILTER_LABELS

    respond_to do |format|
      format.html { render :index }
      format.json do
        render json: {
          brands: @brands
        }, status: :ok
      end
    end
  end

  def show
    # Load product listing scoped to this brand
    load_products_for(request, @brand.products)
  end

  def new
    @brand = Brand.new
  end

  def edit
  end

  def create
    @brand = Brand.new(brand_params)
    if @brand.save
      redirect_to admin_brand_path(@brand), notice: 'Brand was successfully created.'
    else
      render :new
    end
  end

  def update
    if @brand.update(brand_params)
      redirect_to admin_brand_path(@brand), notice: 'Brand was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    if @brand.destroy
      redirect_to admin_brands_path, notice: 'Brand was successfully deleted.'
    else
      redirect_back(fallback_location: admin_brands_path, alert: 'Failed to delete brand.')
    end
  end

  private

  def index_params
    params.permit(
      :q,
      :name,
      :slug,
      :created_after,
      :created_before,
      :sort_by,
      :page,
      :per_page,
      flags: []
    )
  end

  def set_brand
    @brand = Brand.find(params[:id])
  end

  def brand_params
    params.require(:brand).permit(:name, :slug, :logo, :banner, product_ids: [])
  end
end
