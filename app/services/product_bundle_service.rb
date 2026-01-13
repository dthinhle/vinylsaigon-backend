class ProductBundleService
  def self.bundles_for_product(product)
    return [] unless product

    Promotion.active
      .bundle
      .joins(:product_bundles)
      .where(product_bundles: { product_id: product.id })
      .includes(product_bundles: [:product, :product_variant])
      .distinct
  end
end
