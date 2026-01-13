module Api
  class ProductController < Api::BaseController
    def show
      @product = Product.includes(
        :category,
        :brands,
        :product_collections,
        :related_products,
        :product_variants
      ).find_by(slug: params[:slug])
      if @product.nil?
        return render json: { error: 'Product not found' }, status: :not_found
      end

      @product_bundles = ProductBundleService.bundles_for_product(@product)
      @related_products = ProductService.related_products([@product])
      @other_products = ProductService.other_products(@product)
    end
  end
end
