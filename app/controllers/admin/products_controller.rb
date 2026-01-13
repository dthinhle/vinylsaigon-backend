# frozen_string_literal: true

class Admin::ProductsController < Admin::BaseController
  include Admin::ProductListable

  FILTER_LABELS = {
    'q' => 'Search',
    'status' => 'Status',
    'stock_status' => 'Stock Status',
    'min_price' => 'Min Price',
    'max_price' => 'Max Price',
    'sku' => 'SKU',
    'min_stock_quantity' => 'Min Qty',
    'max_stock_quantity' => 'Max Qty',
    'featured' => 'Featured',
    'free_installment_fee' => 'Free Installment',
    'sort_order' => 'Sort Order',
    'sort' => 'Sort',
    'direction' => 'Direction',
    'brand_ids' => 'Brand',
    'category_ids' => 'Category'
  }

  # GET /admin/products
  def index
    load_products_for(request, Product.includes(:product_variants, :brands, category: :parent))

    @filter_params = index_params
    @filter_labels = FILTER_LABELS
    @preload_categories = Category.includes(:parent).order(:title).limit(10).map { |c| [c.id, c.parent ? "#{c.title} (#{c.parent.title})" : c.title] }
    @preload_brands = Brand.order(:name).limit(10).pluck(:id, :name)
    @preload_flags = Product.distinct.pluck(:flags).flatten.compact.uniq.sort.take(10)

    respond_to do |format|
      format.html { render :index }
      format.json do
        render json: {
          products: @products
        }, status: :ok
      end
    end
  end

  # GET /admin/products/:id

  # POST /admin/products
  def new
    @product = Product.new
    @product.product_attributes ||= {}
  end

  def create
    @product = ProductService.create_product(
      product_params_without_variants,
      product_variants_params[:product_variants_attributes],
      params[:product][:single_product_images]
    )
    redirect_to admin_products_path, notice: 'Product was successfully created.'
  rescue StandardError => e
    @product ||= Product.new(product_params_without_variants)
    @product.errors.add(:base, e.message)

    Bugsnag.notify(e) if defined?(Bugsnag)

    Rails.logger.error("Product creation failed: #{e.message}")
    render :new, status: :unprocessable_entity
  end

  def show
    @product = Product.find(params[:id])
    redirect_to edit_admin_product_path(@product)
  end

  # PATCH/PUT /admin/products/:id
  def edit
    @product = Product.find(params[:id])
    @product.product_attributes ||= {}

    first_variant = @product.product_variants.size <= 1 ? @product.product_variants.first : nil
    if first_variant
      @product.original_price = first_variant.original_price
      Rails.logger.info("First variant original price: #{first_variant.original_price} - #{first_variant.original_price}")
      @product.current_price = first_variant.current_price
      Rails.logger.info("First variant current price: #{first_variant.current_price} - #{first_variant.current_price}")
    else
      @product.original_price = nil
      @product.current_price = nil
    end
  end

  def update
    @product = Product.find(params[:id])

    image_params = {
      single_images: product_params[:single_product_images],
      single_remove_ids: params[:images_to_remove]
    }

    result = ProductService.update_product(
      @product,
      product_params_without_variants,
      product_variants_params[:product_variants_attributes],
      image_params
    )

    if result.success
      redirect_to edit_admin_product_path(@product), notice: 'Product was successfully updated.'
    else
      flash[:alert] = result.errors.join("\n")
      @product.errors.add(:base, result.errors.join('; '))
      render :edit, status: :unprocessable_entity
    end
  rescue StandardError => e
    @product.errors.add(:base, e.message)
    Bugsnag.notify(e) if defined?(Bugsnag)

    Rails.logger.error("Product updated failed: #{e.message}")
    render :edit, status: :unprocessable_entity
  end

  # DELETE /admin/products/:id
  def destroy
    @product = Product.unscoped.find(params[:id])
    if @product.destroy
      redirect_back_or_to admin_products_path, notice: 'Product deleted successfully.'
    else
      redirect_back_or_to admin_products_path, alert: 'Failed to delete product.'
    end
  end

  # POST /admin/products/destroy_selected
  def destroy_selected
    ids = params[:product_ids] || params[:ids] || []
    result = ProductService.destroy_selected_products(ids)

    if result[:success]
      flash[:notice] = result[:message]
    else
      flash[:alert] = result[:message]
    end

    respond_to do |format|
      format.html { redirect_to admin_products_path }
      format.json {
        render json: {
          success: result[:success],
          not_found: result[:not_found],
          failed: result[:failed]
        }, status: (result[:success] ? :ok : :unprocessable_entity)
      }
    end
  end

  def variants
    @product = Product.find(params[:id])
    @variants = @product.product_variants.order(:name)

    render json: { variants: @variants.map { |v| { id: v.id, name: v.name } } }
  end

  def revert
    @product = Product.find(params[:id])
    transaction_id = params[:transaction_id]

    if transaction_id.blank?
      redirect_to edit_admin_product_path(@product), alert: 'No version transaction specified.'
      return
    end

    begin
      ProductVersionService.revert_to(@product, transaction_id)
      redirect_to edit_admin_product_path(@product), notice: 'Product reverted successfully.'
    rescue ProductVersionService::RevertError => e
      redirect_to edit_admin_product_path(@product), alert: "Revert failed: #{e.message}"
    rescue StandardError => e
      Rails.logger.error("Product revert failed: #{e.message}")
      redirect_to edit_admin_product_path(@product), alert: 'An error occurred while reverting.'
    end
  end

  def upload_image
    result = ImageUploadService.call(params.permit(:file, :url))

    if result[:success]
      blob = result[:blob]
      image_url = url_for(blob)
      render json: {
        location: image_url,
        meta: {
          title: blob.filename,
          alt: blob.filename,
          dimensions: { width: blob.metadata[:width], height: blob.metadata[:height] },
          fileinput: [{ name: blob.filename, size: blob.byte_size, type: blob.content_type }]
        }
      }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def upload_video
    result = VideoUploadService.call(params.permit(:file))

    if result[:success]
      blob = result[:blob]
      video_url = url_for(blob)
      render json: { location: video_url }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  private

  def index_params
    params.permit(
      :q,
      :status,
      :stock_status,
      :min_price,
      :max_price,
      :sku,
      :min_stock_quantity,
      :max_stock_quantity,
      :featured,
      :free_installment_fee,
      :sort_order,
      :sort_by,
      brand_ids: [],
      category_ids: []
    )
  end

  def product_params_without_variants
    product_params.except(:product_variants_attributes, :single_product_images)
  end

  def product_variants_params
    params.require(:product).permit!.slice(:product_variants_attributes)
  end

  def product_params
    params.require(:product).permit(
      :short_description,
      :current_price,
      :stock_quantity,
      :low_stock_threshold,
      :weight,
      :meta_title,
      :meta_description,
      :sort_order,
      :name,
      :sku,
      :description,
      :gift_content,
      :status,
      :stock_status,
      :category_id,
      :featured,
      :free_installment_fee,
      :original_price,
      :current_price,
      :deleted_at,
      :slug,
      :warranty_months,
      :product_attributes,
      :skip_auto_flags,
      flags: [],
      brand_ids: [],
      category_ids: [],
      product_collection_ids: [],
      product_tags: [],
      related_product_ids: [],
      single_product_images: [],
      images_to_remove: [],
      product_variants_attributes: [
        :id,
        :name,
        :sku,
        :slug,
        :original_price,
        :current_price,
        :status,
        :sort_order,
        :variant_attributes,
        :_destroy,
        remove_image_ids: [],
        product_images: [],
        product_images_positions: [],
        product_images_attributes: [:id, :position, :_destroy],
      ]
    )
  end
end
