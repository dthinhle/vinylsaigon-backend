class Admin::SelectorsController < Admin::BaseController
  SELECTOR_LIMIT = 50
  # GET /admin/selectors/categories
  def categories
    @categories = Category.includes(:parent)

    if params[:q].present?
      @categories = @categories.where('title ILIKE ?', "%#{params[:q]}%")
    end

    @categories = @categories.order(:title).limit(SELECTOR_LIMIT)

    render json: @categories.map { |c|
      {
        id: c.id,
        title: c.parent ? "#{c.title} (#{c.parent.title})" : c.title
      }
    }
  end

  # GET /admin/selectors/brands
  def brands
    @brands = Brand.all

    if params[:q].present?
      @brands = @brands.where('name ILIKE ?', "%#{params[:q]}%")
    end

    @brands = @brands.order(:name).limit(SELECTOR_LIMIT)

    render json: @brands.select(:id, :name)
  end

  # GET /admin/selectors/product_collections
  def product_collections
    @collections = ProductCollection.all

    if params[:q].present?
      @collections = @collections.where('name ILIKE ?', "%#{params[:q]}%")
    end

    @collections = @collections.order(:name).limit(SELECTOR_LIMIT)

    render json: @collections.select(:id, :name)
  end

  # GET /admin/selectors/products
  def products
    @products = Product.all

    if params[:q].present?
      @products = @products.where('name ILIKE ? OR sku ILIKE ?', "%#{params[:q]}%", "%#{params[:q]}%")
    end

    @products = @products.order(:name).limit(SELECTOR_LIMIT)

    render json: @products.map { |p| { id: p.id, name: "#{p.name} (#{p.sku})" } }
  end
end
