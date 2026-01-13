# frozen_string_literal: true

class Admin::ProductVariantsController < Admin::BaseController
  before_action :set_product

  # GET /admin/products/:product_id/variants
  def index
    @product_variants = @product.product_variants
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end
end
