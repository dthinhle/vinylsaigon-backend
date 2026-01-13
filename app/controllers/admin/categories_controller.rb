# frozen_string_literal: true

class Admin::CategoriesController < Admin::BaseController
  include SortableParams
  include Admin::ProductListable

  before_action :set_category, only: [:show, :edit, :update, :destroy]

  FILTER_LABELS = {
    'q' => 'Search',
    'is_root' => 'Is Root',
    'parent_id' => 'Root Category',
    'sort_by' => 'Sort'
  }.freeze

  def index
    filter = CategoryFilterService.new(Category.all, parse_sort_by_params(index_params))
    filtered = filter.call
    @pagy, @categories = pagy(filtered, limit: 25)
    @filter_params = index_params
    @filter_labels = FILTER_LABELS

    @current_sort = params[:sort].to_s
    @current_direction = params[:direction] || 'desc'

    respond_to do |format|
      format.html { render :index }
      format.json { render json: { categories: @categories }, status: :ok }
    end
  end

  # GET /admin/categories/:id
  def show
    # Provide current sort/direction for nested product listing
    @current_sort = params[:sort].to_s
    @current_direction = params[:direction] || 'desc'

    # Load product listing scoped to this category
    load_products_for(request, @category.products)
  end

  # GET /admin/categories/new
  def new
    @category = Category.new
  end

  # GET /admin/categories/:id/edit
  def edit
  end

  # POST /admin/categories
  def create
    permitted = category_params
    attrs = permitted.except(:image)
    @category = Category.new(attrs)

    if @category.save
      if permitted[:image].present?
        @category.image.attach(permitted[:image])
      end
      redirect_to admin_categories_path, notice: 'Category was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /admin/categories/:id
  def update
    permitted = category_params
    attrs = permitted.except(:image)

    if @category.update(attrs)
      if permitted[:image].present?
        @category.image.purge_later if @category.image.attached?
        @category.image.attach(permitted[:image])
      end
      redirect_to admin_categories_path, notice: 'Category was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/categories/:id
  def destroy
    begin
      if @category.destroy
        redirect_to admin_categories_path, notice: 'Category deleted successfully.'
      else
        redirect_to admin_categories_path, alert: 'Failed to delete category.'
      end
    rescue ActiveRecord::DeleteRestrictionError => e
      redirect_to admin_categories_path, alert: e.message
    end
  end

  private

  def index_params
    params.permit(
      :q,
      :is_root,
      :parent_id,
      :page,
      :per_page,
      :sort_by
    )
  end

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(
      :title,
      :slug,
      :description,
      :is_root,
      :parent_id,
      :button_text,
      :image
    )
  end
end
